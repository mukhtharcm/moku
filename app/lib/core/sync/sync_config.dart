import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncConfig extends Equatable {
  final String serverUrl;
  final bool isEnabled;
  final DateTime? lastSyncAt;

  const SyncConfig({
    this.serverUrl = '',
    this.isEnabled = false,
    this.lastSyncAt,
  });

  SyncConfig copyWith({
    String? serverUrl,
    bool? isEnabled,
    DateTime? lastSyncAt,
  }) {
    return SyncConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  List<Object?> get props => [serverUrl, isEnabled, lastSyncAt];
}

enum SyncStatus { disconnected, connecting, connected, syncing, error }

class SyncError {
  final String collection;
  final String message;
  final DateTime timestamp;

  const SyncError({
    required this.collection,
    required this.message,
    required this.timestamp,
  });
}

class SyncConfigState extends Equatable {
  final SyncConfig config;
  final SyncStatus status;
  final String? errorMessage;
  final bool isAuthenticated;
  final List<SyncError> recentErrors;

  const SyncConfigState({
    this.config = const SyncConfig(),
    this.status = SyncStatus.disconnected,
    this.errorMessage,
    this.isAuthenticated = false,
    this.recentErrors = const [],
  });

  SyncConfigState copyWith({
    SyncConfig? config,
    SyncStatus? status,
    String? errorMessage,
    bool? isAuthenticated,
    List<SyncError>? recentErrors,
  }) {
    return SyncConfigState(
      config: config ?? this.config,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      recentErrors: recentErrors ?? this.recentErrors,
    );
  }

  @override
  List<Object?> get props => [config, status, errorMessage, isAuthenticated, recentErrors];
}

class SyncConfigCubit extends Cubit<SyncConfigState> {
  static const _serverUrlKey = 'sync_server_url';
  static const _isEnabledKey = 'sync_is_enabled';
  static const _lastSyncAtKey = 'sync_last_sync_at';

  SyncConfigCubit() : super(const SyncConfigState());

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_serverUrlKey) ?? '';
    final isEnabled = prefs.getBool(_isEnabledKey) ?? false;
    final lastSyncAtMs = prefs.getInt(_lastSyncAtKey);

    emit(state.copyWith(
      config: SyncConfig(
        serverUrl: serverUrl,
        isEnabled: isEnabled,
        lastSyncAt: lastSyncAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncAtMs)
            : null,
      ),
    ));
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
    emit(state.copyWith(
      config: state.config.copyWith(serverUrl: url),
    ));
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isEnabledKey, enabled);
    emit(state.copyWith(
      config: state.config.copyWith(isEnabled: enabled),
      status: enabled ? state.status : SyncStatus.disconnected,
    ));
  }

  Future<void> updateLastSyncAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncAtKey, time.millisecondsSinceEpoch);
    emit(state.copyWith(
      config: state.config.copyWith(lastSyncAt: time),
    ));
  }

  void setStatus(SyncStatus status, {String? errorMessage}) {
    emit(state.copyWith(
      status: status,
      errorMessage: errorMessage,
    ));
  }

  void setAuthenticated(bool authenticated) {
    emit(state.copyWith(
      isAuthenticated: authenticated,
      status: authenticated ? SyncStatus.connected : SyncStatus.disconnected,
    ));
  }

  void reportSyncError(String collection, String message) {
    final errors = [
      SyncError(collection: collection, message: message, timestamp: DateTime.now()),
      ...state.recentErrors,
    ].take(50).toList();
    emit(state.copyWith(
      status: SyncStatus.error,
      errorMessage: message,
      recentErrors: errors,
    ));
  }

  void clearErrors() {
    emit(state.copyWith(
      errorMessage: null,
      recentErrors: [],
    ));
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_isEnabledKey);
    await prefs.remove(_lastSyncAtKey);
    emit(const SyncConfigState());
  }
}
