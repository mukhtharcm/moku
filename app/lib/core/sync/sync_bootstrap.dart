import 'dart:io';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import 'auth_service.dart';
import 'auto_sync_service.dart';
import 'sync_config.dart';
import 'sync_engine.dart';

/// App-scope sync bootstrap.
///
/// Historically, auth + SyncEngine were instantiated inside the Settings
/// screen — which meant auto-sync at launch couldn't work unless the user
/// opened that screen. This bootstrap restores auth and constructs a shared
/// [SyncEngine] at app start so auto-sync runs regardless.
class SyncBootstrap {
  SyncBootstrap({
    required this.database,
    required this.configCubit,
    required this.autoSyncService,
    AuthService? authService,
  }) : authService = authService ?? AuthService();

  final AppDatabase database;
  final SyncConfigCubit configCubit;
  final AutoSyncService autoSyncService;
  final AuthService authService;

  static const _lastIdentityKey = 'sync_last_identity';
  static const _lastSyncAtKey = 'sync_last_sync_at';

  SyncEngine? _engine;

  SyncEngine? get engine => _engine;
  AuthService get auth => authService;

  /// Called once at app startup, after configCubit.loadConfig().
  Future<void> init() async {
    final serverUrl = configCubit.state.config.serverUrl;
    if (serverUrl.isEmpty) return;

    try {
      await authService.init(serverUrl);
    } catch (e) {
      log('auth init failed: $e', name: 'SyncBootstrap');
      return;
    }

    if (authService.isAuthenticated) {
      await _prepareAuthenticatedIdentity(serverUrl);
      configCubit.setAuthenticated(true);
      _buildEngineAndAttach();
    }
  }

  /// Called after a successful login/registration from the Settings screen.
  Future<void> onAuthenticated() async {
    await _prepareAuthenticatedIdentity(configCubit.state.config.serverUrl);
    configCubit.setAuthenticated(true);
    _buildEngineAndAttach();
  }

  /// Called on logout.
  Future<void> onLogout() async {
    await autoSyncService.syncNow().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
    autoSyncService.detach();
    await authService.logout();
    _engine = null;
    // Wipe the lastSyncAt cursor so a reconnected account re-pulls.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncAtKey);
    await configCubit.loadConfig();
  }

  /// Called when the server URL changes.
  Future<void> onServerUrlChanged(String newUrl) async {
    autoSyncService.detach();
    _engine = null;
    if (newUrl.isEmpty) return;
    await authService.init(newUrl);
    if (authService.isAuthenticated) {
      _buildEngineAndAttach();
    }
  }

  void _buildEngineAndAttach() {
    final pb = authService.pb;
    if (pb == null) return;
    _engine = SyncEngine(
      pb: pb,
      db: database,
      onError: (collection, message) {
        configCubit.reportSyncError(collection, message);
      },
    );
    autoSyncService.attach(_engine!);
  }

  Future<void> _prepareAuthenticatedIdentity(String serverUrl) async {
    final userId = authService.userId;
    final normalizedServerUrl = serverUrl.trim();
    if (normalizedServerUrl.isEmpty || userId == null || userId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nextIdentity = '$normalizedServerUrl::$userId';
    final previousIdentity = prefs.getString(_lastIdentityKey);

    if (previousIdentity != null && previousIdentity != nextIdentity) {
      final localAssetPaths = await database.clearAllSyncContent();
      for (final path in localAssetPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          log(
            'identity reset file cleanup failed for $path: $e',
            name: 'SyncBootstrap',
          );
        }
      }

      await prefs.remove(_lastSyncAtKey);
      await configCubit.loadConfig();
      configCubit.clearErrors();
    }

    await prefs.setString(_lastIdentityKey, nextIdentity);
  }
}
