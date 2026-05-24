import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_config.dart';
import 'sync_engine.dart';

/// Reason a sync was triggered. Used for logging/metrics.
enum SyncTrigger {
  startup,
  foreground,
  periodic,
  dirtyBump,
  progressBump,
  background,
  manual,
}

/// App-scoped coordinator for automatic sync.
///
/// Combines several cheap triggers into one well-behaved scheduler:
///   * startup (~5s after launch)
///   * app resumed (when data is stale)
///   * periodic timer (~2m ± jitter while foregrounded)
///   * dirty bump (debounced 10s for general edits)
///   * progress bump (coalesced with a 3m minimum interval, flushed on pause
///     or reader close)
///   * manual Sync Now (bypasses backoff)
///
/// Design constraints addressed:
///   * Single-flight: only one sync runs at a time. Triggers that arrive
///     while a sync is in flight set a `pendingRerun` flag so exactly one
///     follow-up runs afterwards — no events are dropped.
///   * Exponential backoff on failure (1→2→5→15→30 min; capped above the
///     periodic interval so a broken server is hit *less* often than a
///     healthy one).
///   * `lastSyncAt` is only advanced on full success to avoid skipping
///     failed entities forever.
///   * Periodic timer is paused in background; a best-effort flush attempts
///     one quick sync if there are unflushed edits.
///   * All triggers share a 30s suppression window so cold-launch +
///     foreground don't both fire.
class AutoSyncService with WidgetsBindingObserver {
  AutoSyncService({required this.configCubit});

  final SyncConfigCubit configCubit;

  // ---- Trigger timings ---------------------------------------------------
  static const Duration _startupDelay = Duration(seconds: 5);
  static const Duration _periodicInterval = Duration(minutes: 2);
  static const Duration _periodicJitter = Duration(seconds: 20);
  static const Duration _foregroundStaleness = Duration(seconds: 45);
  static const Duration _generalBumpDebounce = Duration(seconds: 10);
  static const Duration _progressBumpMinInterval = Duration(minutes: 3);
  static const Duration _suppressionWindow = Duration(seconds: 30);

  // Backoff cap of 30 min is deliberately ≥ periodic interval so a failing
  // server is never hit more often than a healthy one.
  static const List<Duration> _backoffSchedule = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  // ---- State -------------------------------------------------------------
  SyncEngine? _engine;
  bool _started = false;
  bool _isSyncing = false;
  bool _pendingRerun = false;
  bool _dirtyGeneral = false;
  bool _dirtyProgress = false;
  bool _appInForeground = true;
  int _consecutiveFailures = 0;
  DateTime? _lastRunAt;
  DateTime? _lastProgressSyncAt;
  DateTime? _backoffUntil;

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  Timer? _progressTimer;
  Timer? _startupTimer;
  Timer? _backoffTimer;

  final _random = Random();

  /// Attach a live sync engine (called after successful auth). Safe to call
  /// multiple times — the latest engine wins.
  void attach(SyncEngine engine) {
    _engine = engine;
    _start();
  }

  /// Detach (e.g. on logout). Cancels all timers; queued bumps are dropped.
  void detach() {
    _engine = null;
    _stop();
  }

  /// Set by bootstrap/settings when the user toggles auto-sync on/off.
  void setAutoSyncEnabled(bool enabled) {
    if (enabled) {
      if (_engine != null) _start();
    } else {
      _stop();
    }
  }

  /// Called from mutation sites after any change that should eventually
  /// propagate to the server (bookmark, highlight, collection, library,
  /// session, goal, etc.). Debounced 10s so a burst of edits coalesces
  /// into one sync.
  void bump() {
    if (!_canAutoSync()) return;
    _dirtyGeneral = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_generalBumpDebounce, () {
      _run(SyncTrigger.dirtyBump);
    });
  }

  /// Called from the reader on every page-turn. Reading-progress updates
  /// happen far more often than any other write; we treat them specially
  /// so we don't sync every few seconds during a long read. Instead we schedule at
  /// a minimum interval; [flush] pushes whatever's pending on reader close
  /// or app pause.
  void bumpProgress() {
    if (!_canAutoSync()) return;
    _dirtyProgress = true;
    if (_progressTimer?.isActive ?? false) return;

    final last = _lastProgressSyncAt;
    final wait = last == null
        ? _generalBumpDebounce
        : () {
            final elapsed = DateTime.now().difference(last);
            final remaining = _progressBumpMinInterval - elapsed;
            return remaining.isNegative ? _generalBumpDebounce : remaining;
          }();
    _progressTimer = Timer(wait, () {
      _run(SyncTrigger.progressBump);
    });
  }

  /// Best-effort immediate flush. Called on reader close, app pause, or
  /// logout-time when we want pending edits pushed before we stop.
  void flush() {
    if (!_canAutoSync()) return;
    if (!_dirtyGeneral && !_dirtyProgress) return;
    _run(SyncTrigger.background, bypassSuppression: true);
  }

  /// Force an immediate best-effort run for critical local mutations such as
  /// deletes. This bypasses suppression and one scheduled backoff delay, but
  /// still respects single-flight and auth/config gates.
  void flushNow() {
    if (!_canAutoSync()) return;
    if (!_dirtyGeneral && !_dirtyProgress) return;
    _run(SyncTrigger.background, bypassBackoff: true, bypassSuppression: true);
  }

  /// Manual "Sync Now" from the settings UI. Bypasses backoff and
  /// staleness checks, but still respects single-flight.
  Future<SyncResult?> syncNow() async {
    return _run(
      SyncTrigger.manual,
      bypassBackoff: true,
      bypassSuppression: true,
    );
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  void _start() {
    if (_started) {
      _scheduleStartup();
      _schedulePeriodic();
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _scheduleStartup();
    _schedulePeriodic();
  }

  void _stop() {
    _started = false;
    _startupTimer?.cancel();
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    _progressTimer?.cancel();
    _backoffTimer?.cancel();
    _startupTimer = _periodicTimer = _debounceTimer = _progressTimer =
        _backoffTimer = null;
    _dirtyGeneral = false;
    _dirtyProgress = false;
    _pendingRerun = false;
    _backoffUntil = null;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
  }

  void _scheduleStartup() {
    _startupTimer?.cancel();
    _startupTimer = Timer(_startupDelay, () {
      _run(SyncTrigger.startup);
    });
  }

  void _schedulePeriodic() {
    _periodicTimer?.cancel();
    final jitterMs =
        _random.nextInt(_periodicJitter.inMilliseconds * 2) -
        _periodicJitter.inMilliseconds;
    final interval = _periodicInterval + Duration(milliseconds: jitterMs);
    _periodicTimer = Timer.periodic(interval, (_) {
      if (_appInForeground) _run(SyncTrigger.periodic);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        if (!_canAutoSync()) return;
        final stale =
            _lastRunAt == null ||
            DateTime.now().difference(_lastRunAt!) > _foregroundStaleness;
        if (stale) _run(SyncTrigger.foreground);
        _schedulePeriodic();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _appInForeground = false;
        // Best-effort flush: push any pending edits before we're
        // potentially suspended. Never block the lifecycle call.
        if (_dirtyGeneral || _dirtyProgress) {
          _run(SyncTrigger.background);
        }
        break;
      case AppLifecycleState.detached:
        _appInForeground = false;
        break;
    }
  }

  // -----------------------------------------------------------------------
  // Core run
  // -----------------------------------------------------------------------

  bool _canAutoSync() {
    final s = configCubit.state;
    return _engine != null &&
        s.config.isEnabled &&
        s.config.autoSyncEnabled &&
        s.isAuthenticated;
  }

  Future<SyncResult?> _run(
    SyncTrigger trigger, {
    bool bypassBackoff = false,
    bool bypassSuppression = false,
  }) async {
    final engine = _engine;
    if (engine == null) return null;

    final s = configCubit.state;
    // Manual syncs bypass the auto-enabled gate so users can always sync.
    if (trigger != SyncTrigger.manual) {
      if (!s.config.isEnabled ||
          !s.config.autoSyncEnabled ||
          !s.isAuthenticated) {
        return null;
      }
    } else {
      if (!s.config.isEnabled || !s.isAuthenticated) return null;
    }

    final now = DateTime.now();
    if (!bypassBackoff &&
        _backoffUntil != null &&
        now.isBefore(_backoffUntil!)) {
      return null;
    }

    // Suppression: dedupe startup+foreground colliding.
    if (!bypassSuppression && _lastRunAt != null) {
      final since = DateTime.now().difference(_lastRunAt!);
      if (since < _suppressionWindow &&
          trigger != SyncTrigger.dirtyBump &&
          trigger != SyncTrigger.progressBump) {
        return null;
      }
    }

    // Single-flight: if a sync is already running, queue a follow-up.
    if (_isSyncing) {
      _pendingRerun = true;
      return null;
    }

    _isSyncing = true;
    _lastRunAt = DateTime.now();
    // Capture & clear dirty flags up-front; a new edit during sync re-dirties.
    final wasProgressDirty = _dirtyProgress;
    _dirtyGeneral = false;
    _dirtyProgress = false;
    _debounceTimer?.cancel();
    _progressTimer?.cancel();

    configCubit.setStatus(SyncStatus.syncing);
    developer.log('run: trigger=${trigger.name}', name: 'AutoSync');

    SyncResult? result;
    try {
      result = await engine.syncAll(
        lastSyncAt: configCubit.state.config.lastSyncAt,
      );

      if (result.skippedAlreadyRunning) {
        // Someone else is syncing — try again shortly.
        _pendingRerun = true;
      } else if (result.isFullSuccess) {
        _consecutiveFailures = 0;
        _backoffUntil = null;
        _backoffTimer?.cancel();
        if (result.syncedAt != null) {
          await configCubit.updateLastSyncAt(result.syncedAt!);
        }
        if (wasProgressDirty) _lastProgressSyncAt = DateTime.now();
        configCubit.setStatus(SyncStatus.connected);
      } else {
        _onFailure(result);
      }
    } catch (e, st) {
      developer.log(
        'run failed: $e',
        name: 'AutoSync',
        error: e,
        stackTrace: st,
      );
      _onFailure(null, e.toString());
    } finally {
      _isSyncing = false;
      if (_pendingRerun) {
        _pendingRerun = false;
        // Run again shortly to pick up any edits that came in mid-sync.
        Timer(const Duration(seconds: 2), () {
          _run(SyncTrigger.dirtyBump);
        });
      }
    }
    return result;
  }

  void _onFailure(SyncResult? result, [String? message]) {
    _consecutiveFailures += 1;
    final idx = (_consecutiveFailures - 1).clamp(
      0,
      _backoffSchedule.length - 1,
    );
    final delay = _backoffSchedule[idx];
    developer.log(
      'failure #$_consecutiveFailures — backoff ${delay.inMinutes}m',
      name: 'AutoSync',
    );

    if (message != null) {
      developer.log('failure detail: $message', name: 'AutoSync');
    }
    configCubit.setStatus(SyncStatus.error);
    _backoffUntil = DateTime.now().add(delay);

    _backoffTimer?.cancel();
    _backoffTimer = Timer(delay, () {
      _run(SyncTrigger.periodic);
    });
  }
}

/// Helper to load sync auto-enabled flag synchronously from prefs. Not used
/// at runtime — the cubit owns the source of truth. Kept only for tests.
Future<bool> loadAutoSyncEnabledPref() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('sync_auto_enabled') ?? true;
}
