import SwiftUI
import SwiftData

@main
struct MokuApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                MokuBook.self,
                ReadingProgress.self,
                BookmarkItem.self,
                Highlight.self,
                BookCollection.self,
            ])
            let config = ModelConfiguration(
                "MokuDatabase",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .commands {
            MokuCommands()
        }

        Settings {
            SettingsView()
                .modelContainer(modelContainer)
        }
    }
}
