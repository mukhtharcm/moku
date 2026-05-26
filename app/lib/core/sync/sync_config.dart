import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncConfig extends Equatable {
  final String serverUrl;
  final bool isEnabled;
  final bool autoSyncEnabled;
  final DateTime? lastSyncAt;

  const SyncConfig({
    this.serverUrl = '',
    this.isEnabled = false,
    this.autoSyncEnabled = true,
    this.lastSyncAt,
  });

  SyncConfig copyWith({
    String? serverUrl,
    bool? isEnabled,
    bool? autoSyncEnabled,
    DateTime? lastSyncAt,
  }) {
    return SyncConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      isEnabled: isEnabled ?? this.isEnabled,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  List<Object?> get props =>
      [serverUrl, isEnabled, autoSyncEnabled, lastSyncAt];
}

enum SyncStatus { disconnected, connecting, connected, syncing, error }

/// Granular progress for the current sync run, surfaced to the UI.
class SyncProgress {
  /// Human-readable name of the entity collection being synced
  /// (e.g. "books", "reading_progress").
  final String stage;

  /// How many epub files have been fully downloaded this run.
  final int filesDone;

  /// Total epub files to download this run (known after the initial
  /// record list is fetched). -1 = not yet known.
  final int filesTotal;

  /// Bytes received for the file currently being downloaded.
  final int bytesReceived;

  /// Total bytes for the file currently being downloaded.
  /// -1 = Content-Length not known.
  final int bytesTotal;

  /// Filename being downloaded (for display).
  final String? currentFileName;

  const SyncProgress({
    this.stage = '',
    this.filesDone = 0,
    this.filesTotal = -1,
    this.bytesReceived = 0,
    this.bytesTotal = -1,
    this.currentFileName,
  });

  /// 0.0–1.0 progress for the current file download, or null if unknown.
  double? get fileProgress => (bytesTotal > 0)
      ? (bytesReceived / bytesTotal).clamp(0.0, 1.0)
      : null;

  /// True while an epub file is actively being streamed.
  bool get isDownloading => currentFileName != null;
}

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
  final SyncProgress? progress;

  const SyncConfigState({
    this.config = const SyncConfig(),
    this.status = SyncStatus.disconnected,
    this.errorMessage,
    this.isAuthenticated = false,
    this.recentErrors = const [],
    this.progress,
  });

  SyncConfigState copyWith({
    SyncConfig? config,
    SyncStatus? status,
    String? errorMessage,
    bool? isAuthenticated,
    List<SyncError>? recentErrors,
    SyncProgress? progress,
    bool clearProgress = false,
  }) {
    return SyncConfigState(
      config: config ?? this.config,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      recentErrors: recentErrors ?? this.recentErrors,
      progress: clearProgress ? null : (progress ?? this.progress),
    );
  }

  @override
  List<Object?> get props => [
    config, status, errorMessage, isAuthenticated, recentErrors, progress,
  ];
}

class SyncConfigCubit extends Cubit<SyncConfigState> {
  static const _serverUrlKey = 'sync_server_url';
  static const _isEnabledKey = 'sync_is_enabled';
  static const _autoSyncEnabledKey = 'sync_auto_enabled';
  static const _lastSyncAtKey = 'sync_last_sync_at';

  SyncConfigCubit() : super(const SyncConfigState());

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_serverUrlKey) ?? '';
    final isEnabled = prefs.getBool(_isEnabledKey) ?? false;
    final autoSyncEnabled = prefs.getBool(_autoSyncEnabledKey) ?? true;
    final lastSyncAtMs = prefs.getInt(_lastSyncAtKey);

    emit(state.copyWith(
      config: SyncConfig(
        serverUrl: serverUrl,
        isEnabled: isEnabled,
        autoSyncEnabled: autoSyncEnabled,
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

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, enabled);
    emit(state.copyWith(
      config: state.config.copyWith(autoSyncEnabled: enabled),
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
    final shouldClearProgress = status != SyncStatus.syncing;
    emit(state.copyWith(
      status: status,
      errorMessage: errorMessage,
      clearProgress: shouldClearProgress,
    ));
  }

  /// Update granular download progress during a sync run.
  void setProgress(SyncProgress progress) {
    emit(state.copyWith(progress: progress));
  }

  /// Clear progress (called when a sync run finishes).
  void clearProgress() {
    emit(state.copyWith(clearProgress: true));
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
      errorMessage: null,
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
    await prefs.remove(_autoSyncEnabledKey);
    await prefs.remove(_lastSyncAtKey);
    emit(const SyncConfigState());
  }
}
