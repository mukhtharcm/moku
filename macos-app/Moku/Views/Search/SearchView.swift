import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [OpenLibraryBook] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Discover")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Open Library…", text: $query)
                        .textFieldStyle(.plain)
                        .frame(width: 220)
                        .onChange(of: query) { _, newValue in
                            performSearch(newValue)
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            if query.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Search for books")
                        .font(.headline)
                    Text("Find books on Open Library")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if isSearching {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if results.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(results, id: \.key) { book in
                    HStack(spacing: 12) {
                        AsyncImage(url: book.coverURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.secondary.opacity(0.2)
                        }
                        .frame(width: 50, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(book.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(book.authorString)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let year = book.firstPublishYear {
                                Text(String(year))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
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
                if !Task.isCancelled {
                    results = books
                }
            } catch {
                if !Task.isCancelled {
                    results = []
                }
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

        struct Response: Codable {
            let docs: [OpenLibraryBook]
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.docs
    }
}
