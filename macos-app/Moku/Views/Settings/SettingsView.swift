import SwiftUI

struct SettingsView: View {
    @AppStorage("syncServerURL") private var serverURL = ""
    @AppStorage("syncEnabled") private var syncEnabled = false
    @State private var showResetAlert = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            syncSettings
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 450, height: 300)
        .padding()
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Section("About") {
                HStack {
                    Image(systemName: "bookmark.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Moku")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Data") {
                Button("Reset Onboarding") {
                    UserDefaults.standard.removeObject(forKey: "onboarding_completed")
                }
                .foregroundStyle(.secondary)

                Button("Delete All Books", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .formStyle(.grouped)
        .alert("Delete All Books?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                // Would need model context injection for this
            }
        } message: {
            Text("This will permanently remove all books from your library.")
        }
    }

    // MARK: - Sync

    private var syncSettings: some View {
        Form {
            Section("PocketBase Server") {
                Toggle("Enable Sync", isOn: $syncEnabled)

                TextField("Server URL", text: $serverURL, prompt: Text("https://your-server.com"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!syncEnabled)
            }

            Section {
                Text("Connect to a self-hosted PocketBase server to sync your books, reading progress, highlights, and bookmarks across all your devices.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if syncEnabled && !serverURL.isEmpty {
                Section("Status") {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Ready to sync")
                            .foregroundStyle(.secondary)
                    }

                    Button("Sync Now") {
                        // TODO: Trigger sync
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }
}
