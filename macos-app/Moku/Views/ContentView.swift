import SwiftUI

struct ContentView: View {
    @State private var selectedTab: SidebarTab = .library
    @State private var showOnboarding = !OnboardingManager.isCompleted

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
            } else {
                NavigationSplitView {
                    SidebarView(selectedTab: $selectedTab)
                } detail: {
                    switch selectedTab {
                    case .library:
                        LibraryView()
                    case .collections:
                        CollectionsView()
                    case .search:
                        SearchView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(minWidth: 800, minHeight: 500)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importEPUB)) { _ in
            selectedTab = .library
            NotificationCenter.default.post(name: .triggerImport, object: nil)
        }
    }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case library = "Library"
    case collections = "Collections"
    case search = "Discover"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: "books.vertical"
        case .collections: "square.stack"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab

    var body: some View {
        List(SidebarTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("Moku")
    }
}

extension Notification.Name {
    static let triggerImport = Notification.Name("triggerImport")
}
