import SwiftUI
import SwiftData

@main
struct MokuApp: App {
    let modelContainer: ModelContainer
    @State private var syncVM: SyncViewModel
    @State private var autoSync: AutoSyncCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("syncServerURL") private var syncServerURL = ""

    init() {
        let container: ModelContainer
        do {
            let schema = Schema([
                MokuBook.self,
                ReadingProgress.self,
                BookmarkItem.self,
                Highlight.self,
                BookCollection.self,
                ReadingSession.self,
                ReadingGoal.self,
            ])
            let config = ModelConfiguration(
                "MokuDatabase",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        modelContainer = container

        // App-scope sync stack — must be built at launch so auto-sync
        // doesn't require opening Settings first.
        let vm = SyncViewModel()
        let serverURL = UserDefaults.standard.string(forKey: "syncServerURL") ?? ""
        vm.initialize(serverURL: serverURL)
        _syncVM = State(initialValue: vm)
        _autoSync = State(initialValue: AutoSyncCoordinator(modelContainer: container))

        do {
            try Self.repairLegacyBooks(in: ModelContext(container))
        } catch {
            print("repairLegacyBooks failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncVM)
                .environment(autoSync)
                .task {
                    // Attach once on first appearance. Idempotent while attached.
                    if syncVM.pbClient.isAuthenticated {
                        autoSync.attach(syncVM: syncVM)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: autoSync.onForeground()
                    case .background, .inactive: autoSync.onBackground()
                    @unknown default: break
                    }
                }
        }
        .modelContainer(modelContainer)
        .commands {
            MokuCommands()
        }

        // Reader opens in its own window, identified by book ID
        WindowGroup("Reader", id: "reader", for: String.self) { $bookId in
            if let bookId {
                ReaderWindowView(bookId: bookId)
                    .environment(syncVM)
                    .environment(autoSync)
            }
        }
        .modelContainer(modelContainer)
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
                .modelContainer(modelContainer)
                .environment(syncVM)
                .environment(autoSync)
        }
    }

    private static func repairLegacyBooks(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<MokuBook>()
        let books = try context.fetch(descriptor)

        var didChange = false
        for book in books where book.format == nil || book.format?.isEmpty == true {
            book.format = book.bookFormat.rawValue
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }
}
