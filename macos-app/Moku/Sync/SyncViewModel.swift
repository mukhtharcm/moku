import Foundation
import SwiftData

/// Observable view model for managing sync state in the UI.
@MainActor
@Observable
final class SyncViewModel {
    let pbClient = PocketBaseClient()
    private var syncEngine: SyncEngine?

    var status: SyncStatus = .disconnected
    var errorMessage: String?
    var isSyncing: Bool { status == .syncing }
    var recentErrors: [(collection: String, message: String, date: Date)] = []

    // Auth form state
    var email = ""
    var password = ""
    var isRegistering = false

    enum SyncStatus: String {
        case disconnected
        case connecting
        case connected
        case syncing
        case error
    }

    /// Initialize from stored config, restore auth.
    func initialize(serverURL: String) {
        guard !serverURL.isEmpty else { return }
        pbClient.serverURL = serverURL
        pbClient.restoreAuth()
        if pbClient.isAuthenticated {
            status = .connected
        }
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        status = .connecting
        errorMessage = nil
        do {
            try await pbClient.login(email: email, password: password)
            status = .connected
            email = ""
            password = ""
        } catch {
            status = .error
            errorMessage = error.localizedDescription
        }
    }

    func register() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        status = .connecting
        errorMessage = nil
        do {
            try await pbClient.register(email: email, password: password)
            status = .connected
            email = ""
            password = ""
        } catch {
            status = .error
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        pbClient.logout()
        status = .disconnected
        errorMessage = nil
    }

    func syncNow(modelContext: ModelContext, lastSyncAt: Date?) async -> SyncResult? {
        guard pbClient.isAuthenticated else {
            errorMessage = "Not authenticated"
            return nil
        }
        status = .syncing
        errorMessage = nil
        let engine = SyncEngine(pb: pbClient, modelContext: modelContext)
        engine.onError = { [weak self] collection, message in
            self?.recentErrors.insert((collection: collection, message: message, date: Date()), at: 0)
            if (self?.recentErrors.count ?? 0) > 50 {
                self?.recentErrors.removeLast()
            }
        }
        syncEngine = engine
        do {
            let result = try await engine.syncAll(lastSyncAt: lastSyncAt)
            if result.authFailed {
                status = .error
                errorMessage = "Authentication expired"
            } else if !result.failedCollections.isEmpty {
                status = .error
                errorMessage = "Sync partially failed: \(result.failedCollections.joined(separator: ", "))"
            } else if !result.skippedAlreadyRunning {
                status = .connected
            }
            return result
        } catch {
            status = .error
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
