import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncViewModel.self) private var syncVM
    @Environment(AutoSyncCoordinator.self) private var autoSync
    @AppStorage("syncServerURL") private var serverURL = ""
    @AppStorage("syncEnabled") private var syncEnabled = false
    @AppStorage("syncAutoEnabled") private var autoSyncEnabled = true
    @State private var showResetAlert = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            syncTab
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 480, height: 340)
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(spacing: 0) {
            // App identity
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.14, green: 0.24, blue: 0.29), Color(red: 0.09, green: 0.16, blue: 0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    // Mini bookmark
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(MokuTheme.coral)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Moku")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                    Text("Version 1.1.0 • Your cozy reading companion")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Divider().padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 16) {
                Text("DATA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                    .padding(.top, 16)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Onboarding")
                            .font(.system(size: 13))
                        Text("Show the welcome screens again on next launch")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Reset") {
                        UserDefaults.standard.removeObject(forKey: "onboarding_completed")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete All Books")
                            .font(.system(size: 13))
                        Text("Permanently remove all books from your library")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Delete All", role: .destructive) {
                        showResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .alert("Delete All Books?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {}
        } message: {
            Text("This will permanently remove all books from your library. This cannot be undone.")
        }
    }

    // MARK: - Sync

    private var syncTab: some View {
        @Bindable var syncVM = syncVM
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $syncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Sync")
                            .font(.system(size: 13, weight: .medium))
                        Text("Sync books, progress, and highlights across devices")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(MokuTheme.violet)
                .padding(.top, 20)

                if syncEnabled {
                    Toggle(isOn: Binding(
                        get: { autoSyncEnabled },
                        set: {
                            autoSyncEnabled = $0
                            autoSync.setAutoSyncEnabled($0)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic sync")
                                .font(.system(size: 13, weight: .medium))
                            Text("Sync in the background on launch, resume, and after edits")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(MokuTheme.violet)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("SERVER URL")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .tracking(1)

                        TextField("https://your-server.com", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .onChange(of: serverURL) { _, newValue in
                                syncVM.initialize(serverURL: newValue)
                            }
                    }

                    if !serverURL.isEmpty {
                        if syncVM.pbClient.isAuthenticated {
                            // Authenticated state
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                                Text(syncVM.status == .syncing ? "Syncing…" : "Connected")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let lastSync = SyncService.lastSyncAt {
                                    Text(lastSync, style: .relative)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                                Button("Sync Now") {
                                    Task {
                                        if let result = await syncVM.syncNow(
                                            modelContext: modelContext,
                                            lastSyncAt: SyncService.lastSyncAt
                                        ), let syncedAt = result.syncedAt,
                                           result.failedCollections.isEmpty {
                                            SyncService.lastSyncAt = syncedAt
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(MokuTheme.violet)
                                .controlSize(.small)
                                .disabled(syncVM.isSyncing)

                                Button("Logout") {
                                    syncVM.logout()
                                    autoSync.detach()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            // Login/Register form
                            VStack(alignment: .leading, spacing: 8) {
                                Text(syncVM.isRegistering ? "REGISTER" : "LOGIN")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .tracking(1)

                                TextField("Email", text: $syncVM.email)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))

                                SecureField("Password", text: $syncVM.password)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))

                                HStack {
                                    Button(syncVM.isRegistering ? "Register" : "Login") {
                                        Task {
                                            if syncVM.isRegistering {
                                                await syncVM.register()
                                            } else {
                                                await syncVM.login()
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(MokuTheme.violet)
                                    .controlSize(.small)
                                    .disabled(syncVM.status == .connecting)

                                    Button(syncVM.isRegistering ? "Have an account? Login" : "Create account") {
                                        syncVM.isRegistering.toggle()
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11))
                                    .foregroundStyle(MokuTheme.violet)
                                }
                            }
                        }

                        if let error = syncVM.errorMessage {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            Divider().padding(.horizontal, 20).padding(.top, 20)

            // Info section
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text("About Sync")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text("Moku uses PocketBase for sync. You can either self-host your own server or use a hosted option. Your data stays on your infrastructure.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer()
        }
        .onAppear {
            syncVM.initialize(serverURL: serverURL)
            if syncVM.pbClient.isAuthenticated {
                autoSync.attach(syncVM: syncVM)
            }
        }
        .onChange(of: syncVM.pbClient.isAuthenticated) { _, authed in
            if authed {
                autoSync.attach(syncVM: syncVM)
            }
        }
    }
}
