import SwiftUI

struct ContentView: View {
    @State private var selectedTab: SidebarTab = .library
    @State private var showOnboarding = !OnboardingManager.isCompleted
    @Environment(\.colorScheme) private var colorScheme

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
                    case .shelves:
                        CollectionsView()
                    case .search:
                        SearchView()
                    case .settings:
                        SettingsDetailView()
                    }
                }
                .frame(minWidth: 860, minHeight: 560)
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
    case shelves = "Shelves"
    case search = "Discover"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library: "books.vertical"
        case .shelves: "square.stack"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List(SidebarTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
                .font(.system(size: 13))
        }
        .listStyle(.sidebar)
        .navigationTitle("")
        .safeAreaInset(edge: .top) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(MokuTheme.coral)
                Text("Moku")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .tracking(-0.3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

extension Notification.Name {
    static let triggerImport = Notification.Name("triggerImport")
}
