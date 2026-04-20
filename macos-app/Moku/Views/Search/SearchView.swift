import SwiftUI

struct SearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var results: [OpenLibraryBook] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var hoveredBook: String?

    var body: some View {
        ZStack {
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .ignoresSafeArea()

            if query.isEmpty {
                emptyPrompt
            } else if isSearching {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if results.isEmpty && !query.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(query)\"")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(results, id: \.key) { book in
                            searchResultRow(book)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: 14) {
                Text("Discover")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .tracking(-0.3)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("Search Open Library…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .frame(width: 200)
                        .onChange(of: query) { _, newValue in
                            performSearch(newValue)
                        }
                    if !query.isEmpty {
                        Button { query = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.04))
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                    .opacity(0.95)
            )
            .background(.ultraThinMaterial.opacity(0.5))
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MokuTheme.violet.opacity(0.06))
                    .frame(width: 100, height: 100)
                Image(systemName: "globe")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(MokuTheme.violet.opacity(0.4))
            }
            Text("Search for Books")
                .font(.system(size: 20, weight: .bold, design: .serif))
            Text("Find books on Open Library's\ncatalog of millions of titles")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func searchResultRow(_ book: OpenLibraryBook) -> some View {
        let isHovered = hoveredBook == book.key
        return HStack(spacing: 14) {
            // Cover
            AsyncImage(url: book.coverURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        MokuTheme.coverColor(for: book.title)
                        Image(systemName: "book.closed")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .frame(width: 42, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .lineLimit(1)
                Text(book.authorString)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let year = book.firstPublishYear {
                    Text(String(year))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered
                    ? (colorScheme == .dark ? .white.opacity(0.04) : .black.opacity(0.03))
                    : .clear
                )
        )
        .onHover { hovering in hoveredBook = hovering ? book.key : nil }
    }

    private func performSearch(_ query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            isSearching = true
            do {
                let books = try await OpenLibraryService.search(query: query)
                if !Task.isCancelled { results = books }
            } catch {
                if !Task.isCancelled { results = [] }
            }
            isSearching = false
        }
    }
}

// MARK: - Open Library Models & Service

struct OpenLibraryBook: Codable {
    let key: String
    let title: String
    let authorName: [String]?
    let firstPublishYear: Int?
    let coverId: Int?

    var authorString: String {
        authorName?.joined(separator: ", ") ?? "Unknown Author"
    }

    var coverURL: URL? {
        guard let id = coverId else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(id)-M.jpg")
    }

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverId = "cover_i"
    }
}

enum OpenLibraryService {
    static func search(query: String) async throws -> [OpenLibraryBook] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=20")!
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Response: Codable { let docs: [OpenLibraryBook] }
        return try JSONDecoder().decode(Response.self, from: data).docs
    }
}
