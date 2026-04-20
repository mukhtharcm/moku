import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@MainActor
@Observable
final class LibraryViewModel {
    var books: [MokuBook] = []
    var searchQuery = ""
    var sortMode: SortMode = .recent
    var viewMode: ViewMode = .grid

    private var modelContext: ModelContext?
    private let bookService = BookService()

    enum SortMode: String, CaseIterable {
        case recent = "Recent"
        case title = "Title"
        case author = "Author"
    }

    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
    }

    var filteredBooks: [MokuBook] {
        var result = books

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.author.lowercased().contains(query)
            }
        }

        switch sortMode {
        case .recent:
            result.sort { ($0.updatedAt) > ($1.updatedAt) }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .author:
            result.sort { $0.author.localizedCompare($1.author) == .orderedAscending }
        }

        return result
    }

    var currentlyReading: [MokuBook] {
        books.filter { $0.readingProgress != nil && ($0.readingProgress?.overallProgress ?? 0) > 0 }
            .sorted { ($0.readingProgress?.lastReadAt ?? .distantPast) > ($1.readingProgress?.lastReadAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadBooks()
    }

    func loadBooks() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<MokuBook>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            books = try context.fetch(descriptor)
        } catch {
            print("Failed to fetch books: \(error)")
        }
    }

    func importBook() {
        let panel = NSOpenPanel()

        // Build UTType list for all supported formats
        var types: [UTType] = [.epub]
        types.append(.pdf)
        types.append(.plainText)
        if let zip = UTType(filenameExtension: "cbz") { types.append(zip) }
        if let cbr = UTType(filenameExtension: "cbr") { types.append(cbr) }
        types.append(.html)

        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            do {
                let book = try bookService.importBook(from: url)
                modelContext?.insert(book)
                try modelContext?.save()
            } catch {
                print("Failed to import \(url.lastPathComponent): \(error)")
            }
        }

        loadBooks()
    }

    func deleteBook(_ book: MokuBook) {
        let booksDir = BookService.booksDirectory()
        if let filePath = book.filePath {
            let fileURL = booksDir.appendingPathComponent(filePath)
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let coverPath = book.coverPath {
            let coverURL = booksDir.appendingPathComponent(coverPath)
            try? FileManager.default.removeItem(at: coverURL)
        }

        modelContext?.delete(book)
        try? modelContext?.save()
        loadBooks()
    }
}
