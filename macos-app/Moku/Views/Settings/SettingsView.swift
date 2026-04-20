import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("syncServerURL") private var serverURL = ""
    @AppStorage("syncEnabled") private var syncEnabled = false
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
                    Text("Version 1.0.0 • Your cozy reading companion")
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
        VStack(alignment: .leading, spacing: 0) {
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SERVER URL")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .tracking(1)

                        TextField("https://your-server.com", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }

                    if !serverURL.isEmpty {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Ready to connect")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Sync Now") {}
                                .buttonStyle(.borderedProminent)
                                .tint(MokuTheme.violet)
                                .controlSize(.small)
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
    }
}
