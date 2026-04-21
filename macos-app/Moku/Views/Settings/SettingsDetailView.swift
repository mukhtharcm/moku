import SwiftUI
import SwiftData

/// Full-bleed settings view used inside the main NavigationSplitView detail pane.
/// Matches the warm layout of Library, Shelves, and Discover pages.
struct SettingsDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("syncServerURL") private var serverURL = ""
    @AppStorage("syncEnabled") private var syncEnabled = false
    @State private var showResetAlert = false
    @State private var showDeleteAlert = false
    @State private var onboardingReset = false
    @State private var syncVM = SyncViewModel()

    var body: some View {
        ZStack {
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // About section
                    aboutSection

                    // General section
                    settingsSection(title: "GENERAL") {
                        settingsRow(
                            icon: "arrow.counterclockwise",
                            iconColor: MokuTheme.violet,
                            title: "Reset Onboarding",
                            subtitle: "Show the welcome screens again on next launch"
                        ) {
                            if onboardingReset {
                                Label("Done", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.green)
                            } else {
                                Button("Reset") {
                                    UserDefaults.standard.removeObject(forKey: "onboarding_completed")
                                    withAnimation { onboardingReset = true }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        Divider().padding(.leading, 44)

                        settingsRow(
                            icon: "trash",
                            iconColor: .red.opacity(0.7),
                            title: "Delete All Books",
                            subtitle: "Permanently remove all books from your library"
                        ) {
                            Button("Delete All", role: .destructive) {
                                showDeleteAlert = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    // Sync section
                    settingsSection(title: "SYNC") {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                                .foregroundStyle(MokuTheme.violet)
                                .frame(width: 28, height: 28)

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
                        }
                        .padding(.vertical, 4)

                        if syncEnabled {
                            Divider().padding(.leading, 44)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("SERVER URL")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .tracking(1)
                                    .padding(.leading, 44)

                                TextField("https://your-server.com", text: $serverURL)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                                    .padding(.leading, 44)
                                    .onChange(of: serverURL) { _, newValue in
                                        syncVM.initialize(serverURL: newValue)
                                    }
                            }

                            if !serverURL.isEmpty {
                                if syncVM.pbClient.isAuthenticated {
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
                                                if let syncTime = await syncVM.syncNow(
                                                    modelContext: modelContext,
                                                    lastSyncAt: SyncService.lastSyncAt
                                                ) {
                                                    SyncService.lastSyncAt = syncTime
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(MokuTheme.violet)
                                        .controlSize(.small)
                                        .disabled(syncVM.isSyncing)

                                        Button("Logout") {
                                            syncVM.logout()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding(.leading, 44)
                                } else {
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
                                    .padding(.leading, 44)
                                }

                                if let error = syncVM.errorMessage {
                                    Text(error)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red.opacity(0.8))
                                        .lineLimit(2)
                                        .padding(.leading, 44)
                                }
                            }
                        }

                        Divider().padding(.leading, 44)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .frame(width: 28, height: 28)

                            Text("Moku uses PocketBase for sync. You can self-host your own server or use a hosted option. Your data stays on your infrastructure.")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .lineSpacing(2)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(24)
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .tracking(-0.3)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                    .opacity(0.95)
            )
            .background(.ultraThinMaterial.opacity(0.5))
        }
        .alert("Delete All Books?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                deleteAllBooks()
            }
        } message: {
            Text("This will permanently remove all books from your library. This cannot be undone.")
        }
        .onAppear {
            syncVM.initialize(serverURL: serverURL)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.14, green: 0.24, blue: 0.29), Color(red: 0.09, green: 0.16, blue: 0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                Image(systemName: "bookmark.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(MokuTheme.coral)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Moku")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .tracking(-0.3)
                Text("Version 1.1.0")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Your cozy reading companion")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    // MARK: - Section builder

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(1.2)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MokuTheme.cornerRadiusMedium)
                    .fill(colorScheme == .dark ? MokuTheme.nightCard : MokuTheme.paperWhite)
                    .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
            )
        }
    }

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            trailing()
        }
        .padding(.vertical, 4)
    }

    private func deleteAllBooks() {
        let descriptor = FetchDescriptor<MokuBook>()
        guard let books = try? modelContext.fetch(descriptor) else { return }
        for book in books {
            modelContext.delete(book)
        }
        try? modelContext.save()
    }
}
