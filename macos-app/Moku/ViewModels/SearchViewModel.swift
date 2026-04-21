import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var catalogs: [DiscoverCatalogSource] = []
    var selectedCatalogID: String?
    var results: [DiscoverCatalogBook] = []
    var query = ""
    var isSearching = false
    var errorMessage: String?
    var downloadingBookIDs: Set<String> = []

    private let catalogService = DiscoverCatalogService()
    private let bookService = BookService()
    private var searchTask: Task<Void, Never>?

    var selectedCatalog: DiscoverCatalogSource? {
        catalogs.first(where: { $0.id == selectedCatalogID }) ?? catalogs.first
    }

    func loadCatalogs() {
        catalogs = catalogService.loadCatalogs()
        if selectedCatalogID == nil {
            selectedCatalogID = catalogs.first?.id
        } else if selectedCatalog == nil {
            selectedCatalogID = catalogs.first?.id
        }
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        searchTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            errorMessage = nil
            results = []
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmed)
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        results = []
        errorMessage = nil
        isSearching = false
    }

    func selectCatalog(_ id: String) {
        selectedCatalogID = id
        errorMessage = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            updateQuery(query)
        }
    }

    func addCustomCatalog(title: String, url: String) async throws {
        let added = try await catalogService.addCustomCatalog(title: title, urlString: url)
        catalogs = catalogService.loadCatalogs()
        selectedCatalogID = added.id

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            await performSearch(trimmed)
        }
    }

    func removeCatalog(_ catalog: DiscoverCatalogSource) async {
        catalogService.removeCustomCatalog(id: catalog.id)
        catalogs = catalogService.loadCatalogs()
        if selectedCatalogID == catalog.id {
            selectedCatalogID = catalogs.first?.id
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            await performSearch(trimmed)
        }
    }

    func download(_ book: DiscoverCatalogBook, modelContext: ModelContext) async throws {
        guard let acquisition = book.preferredAcquisition else { return }

        downloadingBookIDs.insert(book.id)
        var downloadedURL: URL?
        defer {
            downloadingBookIDs.remove(book.id)
            if let downloadedURL {
                try? FileManager.default.removeItem(at: downloadedURL)
            }
        }

        downloadedURL = try await catalogService.downloadAcquisition(
            acquisition,
            suggestedName: book.title
        )
        guard let downloadedURL else { return }

        let importedBook = try bookService.importBook(from: downloadedURL)
        modelContext.insert(importedBook)
        try modelContext.save()
    }

    private func performSearch(_ query: String) async {
        guard let catalog = selectedCatalog else {
            errorMessage = "No catalog selected."
            results = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await catalogService.searchBooks(in: catalog, query: query)
            errorMessage = nil
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
}
