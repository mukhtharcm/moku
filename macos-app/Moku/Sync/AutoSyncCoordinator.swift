import Foundation
import SwiftData
import SwiftUI
import Network
import Combine

/// Reason a sync was triggered. Used for logging.
enum AutoSyncTrigger: String {
    case startup
    case foreground
    case periodic
    case reconnect
    case dirtyBump
    case progressBump
    case backgroundFlush
    case manual
}

/// App-scoped automatic sync coordinator for the macOS app.
///
/// Mirrors the Flutter `AutoSyncService`:
///   * startup (~5s after launch)
///   * app resumed / foregrounded (when data is stale)
///   * periodic timer (~15m ± jitter)
///   * network reconnect (via `NWPathMonitor`)
///   * dirty bump (debounced 30s after any SwiftData save)
///   * progress bump (coalesced with 3m min interval, flushed on pause)
///   * manual
///
/// Observes `ModelContext.didSave` to detect edits without having to wire
/// bumps in every write site — a single SwiftData save fires the debounce.
@MainActor
@Observable
final class AutoSyncCoordinator {
    // MARK: - Tunables
    private let periodicInterval: TimeInterval = 15 * 60  // 15 min
    private let periodicJitter: TimeInterval = 2 * 60     // ± 2 min
    private let foregroundStaleAfter: TimeInterval = 2 * 60
    private let debounceGeneral: TimeInterval = 30
    private let progressMinInterval: TimeInterval = 3 * 60
    private let startupDelay: TimeInterval = 5
    private let suppressionWindow: TimeInterval = 30
    /// Backoff schedule in seconds. Cap ≥ periodic so a broken server isn't
    /// hit MORE often than when healthy.
    private let backoffSchedule: [TimeInterval] = [60, 120, 300, 900, 1800]

    // MARK: - Dependencies
    private weak var syncVM: SyncViewModel?
    private let modelContainer: ModelContainer
    /// Shared context just for running syncs.
    private let syncContext: ModelContext

    // MARK: - State
    private var periodicTimer: Timer?
    private var debounceTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var backoffTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var pathQueue = DispatchQueue(label: "moku.autosync.path")
    private var wasOnline = true
    private var saveObserver: Any?

    private var dirtyGeneral = false
    private var dirtyProgress = false
    private var isSyncing = false
    private var pendingRerun = false
    private var consecutiveFailures = 0
    private var lastRunAt: Date?
    private var lastProgressSyncAt: Date?
    private var isAttached = false

    @ObservationIgnored
    var autoSyncEnabled: Bool = true {
        didSet {
            if autoSyncEnabled, isAttached {
                start()
            } else {
                stop()
            }
        }
    }

    // MARK: - Init

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.syncContext = ModelContext(modelContainer)
        self.autoSyncEnabled = UserDefaults.standard.object(forKey: "syncAutoEnabled") as? Bool ?? true
    }

    deinit {
        // No cleanup here — coordinator lives for the app lifetime.
        // Tear-down on logout is handled by `detach()`.
    }

    // MARK: - Lifecycle

    /// Called once the SyncViewModel is authenticated and ready.
    func attach(syncVM: SyncViewModel) {
        self.syncVM = syncVM
        isAttached = true
        startPathMonitor()
        startSaveObserver()
        if autoSyncEnabled {
            start()
        }
    }

    func detach() {
        isAttached = false
        stop()
        pathMonitor?.cancel()
        pathMonitor = nil
        if let obs = saveObserver {
            NotificationCenter.default.removeObserver(obs)
            saveObserver = nil
        }
    }

    private func start() {
        schedulePeriodic()
        // Startup sync after a small delay so UI settles.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.startupDelay ?? 5) * 1_000_000_000)
            await self?.run(trigger: .startup)
        }
    }

    private func stop() {
        periodicTimer?.invalidate()
        periodicTimer = nil
        debounceTask?.cancel()
        progressTask?.cancel()
        backoffTask?.cancel()
    }

    // MARK: - Triggers

    /// Call on any user-visible edit (bookmark/highlight/collection/library/session/goal).
    func bump() {
        guard autoSyncEnabled, isAttached else { return }
        dirtyGeneral = true
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.debounceGeneral * 1_000_000_000))
            if Task.isCancelled { return }
            await self.run(trigger: .dirtyBump)
        }
    }

    /// Call on reading-progress saves (frequent: every page turn).
    func bumpProgress() {
        guard autoSyncEnabled, isAttached else { return }
        dirtyProgress = true
        // If there's already a general bump pending, ride that.
        guard debounceTask == nil || debounceTask!.isCancelled else { return }

        let now = Date()
        if let last = lastProgressSyncAt,
           now.timeIntervalSince(last) < progressMinInterval {
            // Not yet — schedule to run at minInterval boundary.
            let remaining = progressMinInterval - now.timeIntervalSince(last)
            progressTask?.cancel()
            progressTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                if Task.isCancelled { return }
                await self.run(trigger: .progressBump)
            }
        } else {
            // Min interval already passed — debounce like general bump.
            progressTask?.cancel()
            progressTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.debounceGeneral * 1_000_000_000))
                if Task.isCancelled { return }
                await self.run(trigger: .progressBump)
            }
        }
    }

    /// Call on scene background / reader close. Forces any dirty state to sync.
    func flush() {
        guard autoSyncEnabled, isAttached else { return }
        guard dirtyGeneral || dirtyProgress else { return }
        debounceTask?.cancel()
        progressTask?.cancel()
        Task { @MainActor [weak self] in
            await self?.run(trigger: .backgroundFlush)
        }
    }

    /// User-initiated sync. Bypasses backoff and debounce.
    @discardableResult
    func syncNow() async -> SyncResult? {
        backoffTask?.cancel()
        return await run(trigger: .manual)
    }

    /// ScenePhase foreground handler.
    func onForeground() {
        guard autoSyncEnabled, isAttached else { return }
        let stale: Bool
        if let last = lastRunAt {
            stale = Date().timeIntervalSince(last) >= foregroundStaleAfter
        } else {
            stale = true
        }
        guard stale else { return }
        Task { @MainActor [weak self] in
            await self?.run(trigger: .foreground)
        }
    }

    /// ScenePhase background handler.
    func onBackground() {
        flush()
    }

    // MARK: - Periodic & connectivity

    private func schedulePeriodic() {
        periodicTimer?.invalidate()
        let jitter = Double.random(in: -periodicJitter...periodicJitter)
        let interval = periodicInterval + jitter
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.run(trigger: .periodic)
                self?.schedulePeriodic()
            }
        }
    }

    private func startPathMonitor() {
        pathMonitor?.cancel()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let isOnline = path.status == .satisfied
                let justReconnected = isOnline && !self.wasOnline
                self.wasOnline = isOnline
                if justReconnected {
                    await self.run(trigger: .reconnect)
                }
            }
        }
        monitor.start(queue: pathQueue)
        pathMonitor = monitor
    }

    private func startSaveObserver() {
        if let obs = saveObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        // SwiftData posts this whenever any ModelContext saves.
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract Sendable info on the posting queue before hopping.
            let info = notification.userInfo ?? [:]
            var touched = Set<String>()
            for key in ["inserted", "updated", "deleted"] {
                if let ids = info[key] as? [PersistentIdentifier] {
                    for id in ids {
                        touched.insert(String(describing: id.entityName ?? ""))
                    }
                }
            }
            let capturedTouched = touched
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isSyncing { return }
                self.bumpFromSave(touchedTypes: capturedTouched)
            }
        }
    }

    private func bumpFromSave(touchedTypes: Set<String>) {
        // Distinguish progress-only saves from general saves.
        let onlyProgress = !touchedTypes.isEmpty &&
            touchedTypes.subtracting(["ReadingProgress"]).isEmpty
        if onlyProgress {
            bumpProgress()
        } else {
            bump()
        }
    }

    // MARK: - Run

    @discardableResult
    private func run(trigger: AutoSyncTrigger) async -> SyncResult? {
        guard isAttached, let syncVM, syncVM.pbClient.isAuthenticated else {
            return nil
        }
        // Suppress rapid back-to-back runs (startup + foreground).
        if trigger != .manual && trigger != .dirtyBump && trigger != .progressBump {
            if let last = lastRunAt,
               Date().timeIntervalSince(last) < suppressionWindow {
                return nil
            }
        }
        if isSyncing {
            pendingRerun = true
            return nil
        }

        isSyncing = true
        lastRunAt = Date()
        let wasProgressDirty = dirtyProgress
        dirtyGeneral = false
        dirtyProgress = false
        debounceTask?.cancel()
        progressTask?.cancel()

        print("[AutoSync] run trigger=\(trigger.rawValue)")

        let result = await syncVM.syncNow(
            modelContext: syncContext,
            lastSyncAt: SyncService.lastSyncAt
        )

        defer { isSyncing = false }

        if let result {
            if result.skippedAlreadyRunning {
                pendingRerun = true
            } else if result.authFailed {
                onFailure(result: result)
            } else if result.failedCollections.isEmpty,
                      let syncedAt = result.syncedAt {
                consecutiveFailures = 0
                backoffTask?.cancel()
                SyncService.lastSyncAt = syncedAt
                if wasProgressDirty {
                    lastProgressSyncAt = Date()
                }
            } else {
                onFailure(result: result)
            }
        } else {
            onFailure(result: nil)
        }

        if pendingRerun {
            pendingRerun = false
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.run(trigger: .dirtyBump)
            }
        }
        return result
    }

    private func onFailure(result: SyncResult?) {
        consecutiveFailures += 1
        let idx = min(consecutiveFailures - 1, backoffSchedule.count - 1)
        let delay = backoffSchedule[idx]
        print("[AutoSync] failure #\(consecutiveFailures) — backoff \(Int(delay))s")
        backoffTask?.cancel()
        backoffTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await self?.run(trigger: .periodic)
        }
    }
}

// Convenience for persisting toggle.
extension AutoSyncCoordinator {
    func setAutoSyncEnabled(_ enabled: Bool) {
        autoSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "syncAutoEnabled")
    }
}
