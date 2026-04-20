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

        // Reader opens in its own window, identified by book ID
        WindowGroup("Reader", id: "reader", for: String.self) { $bookId in
            if let bookId {
                ReaderWindowView(bookId: bookId)
            }
        }
        .modelContainer(modelContainer)
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
                .modelContainer(modelContainer)
        }
    }
}
