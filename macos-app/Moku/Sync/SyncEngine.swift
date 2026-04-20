import Foundation
import SwiftData
import CryptoKit

/// Bidirectional PocketBase sync engine for the macOS app.
/// Follows the same protocol as the Flutter sync engine:
/// Books → ReadingProgress → Bookmarks → Highlights → Collections → CollectionBooks
@MainActor
final class SyncEngine {
    let pb: PocketBaseClient
    let modelContext: ModelContext
    private var lastSyncAt: Date?

    init(pb: PocketBaseClient, modelContext: ModelContext) {
        self.pb = pb
        self.modelContext = modelContext
    }

    /// Run a full bidirectional sync. Returns the sync timestamp.
    func syncAll(lastSyncAt: Date? = nil) async throws -> Date {
        self.lastSyncAt = lastSyncAt
        let syncTime = Date()

        try await syncBooks()
        try await syncReadingProgress()
        try await syncBookmarks()
        try await syncHighlights()
        try await syncCollections()
        try await syncCollectionBooks()

        return syncTime
    }

    // MARK: - Books

    private func syncBooks() async throws {
        try await pushBooks()
        try await pullBooks()
    }

    private func pushBooks() async throws {
        guard let userId = pb.userId else { return }
        let books = try modelContext.fetch(FetchDescriptor<MokuBook>())

        // Push new books (no remoteId)
        for book in books where book.remoteId == nil {
            do {
                var files: [(fieldName: String, filePath: String, fileName: String)] = []
                if let filePath = book.filePath {
                    let fullPath = BookService.booksDirectory()
                        .appendingPathComponent(filePath).path
                    if FileManager.default.fileExists(atPath: fullPath) {
                        files.append((fieldName: "epub_file", filePath: fullPath,
                                      fileName: URL(fileURLWithPath: filePath).lastPathComponent))
                    }
                }
                if let coverPath = book.coverPath {
                    let fullCoverPath = BookService.booksDirectory()
                        .appendingPathComponent(coverPath).path
                    if FileManager.default.fileExists(atPath: fullCoverPath) {
                        files.append((fieldName: "cover_image", filePath: fullCoverPath,
                                      fileName: URL(fileURLWithPath: coverPath).lastPathComponent))
                    }
                }

                let record = try await pb.createWithFiles(
                    collection: "books",
                    body: bookToMap(book, userId: userId),
                    files: files
                )
                book.remoteId = record["id"] as? String
                try? modelContext.save()
            } catch {
                // Skip on error, continue with others
            }
        }

        // Push updated books (have remoteId, updated after last sync)
        if let lastSync = lastSyncAt {
            for book in books where book.remoteId != nil && book.updatedAt > lastSync {
                do {
                    _ = try await pb.update(
                        collection: "books",
                        id: book.remoteId!,
                        body: bookToMap(book, userId: userId)
                    )
                } catch {
                    // Skip on error
                }
            }
        }
    }

    private func pullBooks() async throws {
        let records = try await fetchRecords("books")

        for record in records {
            let remoteId = record["id"] as? String ?? ""

            if let existing = findBookByRemoteId(remoteId) {
                // LWW: update if remote is newer
                if let updatedStr = record["updated"] as? String,
                   let remoteUpdated = parseDate(updatedStr),
                   remoteUpdated > existing.updatedAt {
                    updateBookFromRecord(existing, record: record)
                }
            } else {
                // Check by file hash
                let fileHash = record["file_hash"] as? String ?? ""
                if !fileHash.isEmpty, let existingByHash = findBookByHash(fileHash) {
                    existingByHash.remoteId = remoteId
                    try? modelContext.save()
                } else {
                    // Download and create new book
                    await downloadAndCreateBook(record)
                }
            }
        }
    }

    private func downloadAndCreateBook(_ record: [String: Any]) async {
        do {
            let epubFilename = record["epub_file"] as? String ?? ""
            guard !epubFilename.isEmpty,
                  let downloadURL = pb.fileURL(record: record, filename: epubFilename) else { return }

            let fileData = try await pb.downloadFile(url: downloadURL)
            let remoteId = record["id"] as? String ?? UUID().uuidString
            let booksDir = BookService.booksDirectory()
            let localPath = "\(remoteId)_\(epubFilename)"
            let fullPath = booksDir.appendingPathComponent(localPath)
            try? FileManager.default.createDirectory(at: fullPath.deletingLastPathComponent(),
                                                      withIntermediateDirectories: true)
            try fileData.write(to: fullPath)

            // Download cover if available
            var coverLocalPath: String?
            let coverFilename = record["cover_image"] as? String ?? ""
            if !coverFilename.isEmpty, let coverURL = pb.fileURL(record: record, filename: coverFilename) {
                let coverData = try await pb.downloadFile(url: coverURL)
                let coverPath = "covers/\(remoteId)_\(coverFilename)"
                let fullCoverPath = booksDir.appendingPathComponent(coverPath)
                try? FileManager.default.createDirectory(at: fullCoverPath.deletingLastPathComponent(),
                                                          withIntermediateDirectories: true)
                try coverData.write(to: fullCoverPath)
                coverLocalPath = coverPath
            }

            let formatStr = record["format"] as? String ?? "epub"
            let book = MokuBook(
                id: "pb_\(String(remoteId.prefix(11)))",
                title: record["title"] as? String ?? "Unknown",
                author: record["author"] as? String ?? "Unknown",
                bookDescription: record["description"] as? String,
                coverPath: coverLocalPath,
                filePath: localPath,
                format: BookFormat(rawValue: formatStr) ?? .epub,
                isbn: record["isbn"] as? String,
                language: record["language"] as? String,
                publisher: record["publisher"] as? String,
                totalChapters: record["total_chapters"] as? Int ?? 0,
                fileHash: record["file_hash"] as? String,
                remoteId: remoteId
            )
            modelContext.insert(book)
            try? modelContext.save()
        } catch {
            // Skip failed downloads
        }
    }

    // MARK: - Reading Progress

    private func syncReadingProgress() async throws {
        try await pushReadingProgress()
        try await pullReadingProgress()
    }

    private func pushReadingProgress() async throws {
        guard let userId = pb.userId else { return }
        let allProgress = try modelContext.fetch(FetchDescriptor<ReadingProgress>())

        for progress in allProgress {
            guard let bookRemoteId = progress.book?.remoteId else { continue }

            if progress.remoteId == nil {
                do {
                    let record = try await pb.create(collection: "reading_progress", body: [
                        "book": bookRemoteId,
                        "user": userId,
                        "current_chapter": progress.currentChapter,
                        "chapter_progress": progress.chapterProgress,
                        "overall_progress": progress.overallProgress,
                        "last_position": progress.lastPosition ?? "",
                        "last_read_at": isoString(progress.lastReadAt),
                    ] as [String: Any])
                    progress.remoteId = record["id"] as? String
                    try? modelContext.save()
                } catch {
                    // Skip
                }
            } else if let lastSync = lastSyncAt, progress.updatedAt > lastSync {
                do {
                    _ = try await pb.update(collection: "reading_progress", id: progress.remoteId!, body: [
                        "current_chapter": progress.currentChapter,
                        "chapter_progress": progress.chapterProgress,
                        "overall_progress": progress.overallProgress,
                        "last_position": progress.lastPosition ?? "",
                        "last_read_at": isoString(progress.lastReadAt),
                    ] as [String: Any])
                } catch {
                    // Skip
                }
            }
        }
    }

    private func pullReadingProgress() async throws {
        let records = try await fetchRecords("reading_progress")

        for record in records {
            let bookRemoteId = record["book"] as? String ?? ""
            guard let localBook = findBookByRemoteId(bookRemoteId) else { continue }
            let remoteId = record["id"] as? String ?? ""

            if let existing = findProgressByRemoteId(remoteId) {
                if let updatedStr = record["updated"] as? String,
                   let remoteUpdated = parseDate(updatedStr),
                   remoteUpdated > existing.updatedAt {
                    existing.currentChapter = record["current_chapter"] as? Int ?? 0
                    existing.chapterProgress = record["chapter_progress"] as? Double ?? 0
                    existing.overallProgress = record["overall_progress"] as? Double ?? 0
                    existing.lastPosition = record["last_position"] as? String
                    if let lastReadStr = record["last_read_at"] as? String {
                        existing.lastReadAt = parseDate(lastReadStr) ?? Date()
                    }
                    existing.updatedAt = Date()
                    try? modelContext.save()
                }
            } else {
                let progress = ReadingProgress(
                    id: "rp_\(String(remoteId.prefix(11)))",
                    book: localBook,
                    currentChapter: record["current_chapter"] as? Int ?? 0,
                    chapterProgress: record["chapter_progress"] as? Double ?? 0,
                    overallProgress: record["overall_progress"] as? Double ?? 0,
                    lastPosition: record["last_position"] as? String,
                    remoteId: remoteId
                )
                modelContext.insert(progress)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Bookmarks

    private func syncBookmarks() async throws {
        try await pushBookmarks()
        try await pullBookmarks()
    }

    private func pushBookmarks() async throws {
        guard let userId = pb.userId else { return }
        let allBookmarks = try modelContext.fetch(FetchDescriptor<BookmarkItem>())

        for bookmark in allBookmarks where bookmark.remoteId == nil {
            guard let bookRemoteId = bookmark.book?.remoteId else { continue }
            do {
                let record = try await pb.create(collection: "bookmarks", body: [
                    "book": bookRemoteId,
                    "user": userId,
                    "chapter_index": bookmark.chapterIndex,
                    "cfi": bookmark.cfi ?? "",
                    "title": bookmark.title,
                ] as [String: Any])
                bookmark.remoteId = record["id"] as? String
                try? modelContext.save()
            } catch {
                // Skip
            }
        }
    }

    private func pullBookmarks() async throws {
        let records = try await fetchRecords("bookmarks")

        for record in records {
            let bookRemoteId = record["book"] as? String ?? ""
            guard let localBook = findBookByRemoteId(bookRemoteId) else { continue }
            let remoteId = record["id"] as? String ?? ""

            let existing = localBook.bookmarks.first { $0.remoteId == remoteId }
            if existing == nil {
                let bookmark = BookmarkItem(
                    id: "bm_\(String(remoteId.prefix(11)))",
                    book: localBook,
                    chapterIndex: record["chapter_index"] as? Int ?? 0,
                    cfi: record["cfi"] as? String,
                    title: record["title"] as? String ?? "Bookmark",
                    remoteId: remoteId
                )
                modelContext.insert(bookmark)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Highlights

    private func syncHighlights() async throws {
        try await pushHighlights()
        try await pullHighlights()
    }

    private func pushHighlights() async throws {
        guard let userId = pb.userId else { return }
        let allHighlights = try modelContext.fetch(FetchDescriptor<Highlight>())

        // Push new
        for highlight in allHighlights where highlight.remoteId == nil {
            guard let bookRemoteId = highlight.book?.remoteId else { continue }
            do {
                let record = try await pb.create(collection: "highlights", body: [
                    "book": bookRemoteId,
                    "user": userId,
                    "chapter_index": highlight.chapterIndex,
                    "start_cfi": highlight.startCfi ?? "",
                    "end_cfi": highlight.endCfi ?? "",
                    "selected_text": highlight.selectedText,
                    "color": highlight.color,
                    "note": highlight.note ?? "",
                ] as [String: Any])
                highlight.remoteId = record["id"] as? String
                try? modelContext.save()
            } catch {
                // Skip
            }
        }

        // Push updated
        if let lastSync = lastSyncAt {
            for highlight in allHighlights where highlight.remoteId != nil && highlight.updatedAt > lastSync {
                do {
                    _ = try await pb.update(collection: "highlights", id: highlight.remoteId!, body: [
                        "selected_text": highlight.selectedText,
                        "color": highlight.color,
                        "note": highlight.note ?? "",
                    ])
                } catch {
                    // Skip
                }
            }
        }
    }

    private func pullHighlights() async throws {
        let records = try await fetchRecords("highlights")

        for record in records {
            let bookRemoteId = record["book"] as? String ?? ""
            guard let localBook = findBookByRemoteId(bookRemoteId) else { continue }
            let remoteId = record["id"] as? String ?? ""

            let existing = localBook.highlights.first { $0.remoteId == remoteId }
            if let existing {
                if let updatedStr = record["updated"] as? String,
                   let remoteUpdated = parseDate(updatedStr),
                   remoteUpdated > existing.updatedAt {
                    existing.selectedText = record["selected_text"] as? String ?? existing.selectedText
                    existing.color = record["color"] as? String ?? existing.color
                    existing.note = record["note"] as? String
                    existing.updatedAt = Date()
                    try? modelContext.save()
                }
            } else {
                let highlight = Highlight(
                    id: "hl_\(String(remoteId.prefix(11)))",
                    book: localBook,
                    chapterIndex: record["chapter_index"] as? Int ?? 0,
                    startCfi: record["start_cfi"] as? String,
                    endCfi: record["end_cfi"] as? String,
                    selectedText: record["selected_text"] as? String ?? "",
                    color: record["color"] as? String ?? "#FFEB3B",
                    note: record["note"] as? String,
                    remoteId: remoteId
                )
                modelContext.insert(highlight)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Collections

    private func syncCollections() async throws {
        try await pushCollections()
        try await pullCollections()
    }

    private func pushCollections() async throws {
        guard let userId = pb.userId else { return }
        let allCollections = try modelContext.fetch(FetchDescriptor<BookCollection>())

        for collection in allCollections where collection.remoteId == nil {
            do {
                let record = try await pb.create(collection: "collections", body: [
                    "name": collection.name,
                    "description": collection.collectionDescription ?? "",
                    "user": userId,
                ])
                collection.remoteId = record["id"] as? String
                try? modelContext.save()
            } catch {
                // Skip
            }
        }

        if let lastSync = lastSyncAt {
            for collection in allCollections where collection.remoteId != nil && collection.updatedAt > lastSync {
                do {
                    _ = try await pb.update(collection: "collections", id: collection.remoteId!, body: [
                        "name": collection.name,
                        "description": collection.collectionDescription ?? "",
                    ])
                } catch {
                    // Skip
                }
            }
        }
    }

    private func pullCollections() async throws {
        let records = try await fetchRecords("collections")

        for record in records {
            let remoteId = record["id"] as? String ?? ""
            let existing = findCollectionByRemoteId(remoteId)

            if let existing {
                if let updatedStr = record["updated"] as? String,
                   let remoteUpdated = parseDate(updatedStr),
                   remoteUpdated > existing.updatedAt {
                    existing.name = record["name"] as? String ?? existing.name
                    existing.collectionDescription = record["description"] as? String
                    existing.updatedAt = Date()
                    try? modelContext.save()
                }
            } else {
                let col = BookCollection(
                    id: "col_\(String(remoteId.prefix(10)))",
                    name: record["name"] as? String ?? "Untitled",
                    collectionDescription: record["description"] as? String,
                    remoteId: remoteId
                )
                modelContext.insert(col)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Collection Books (junction)

    private func syncCollectionBooks() async throws {
        try await pushCollectionBooks()
        try await pullCollectionBooks()
    }

    private func pushCollectionBooks() async throws {
        let allCollections = try modelContext.fetch(FetchDescriptor<BookCollection>())

        for collection in allCollections {
            guard let colRemoteId = collection.remoteId else { continue }

            for book in collection.books {
                guard let bookRemoteId = book.remoteId else { continue }

                // Check if already exists on server
                do {
                    let existing = try await pb.getFullList(
                        collection: "collection_books",
                        filter: "collection = \"\(colRemoteId)\" && book = \"\(bookRemoteId)\""
                    )
                    if existing.isEmpty {
                        _ = try await pb.create(collection: "collection_books", body: [
                            "collection": colRemoteId,
                            "book": bookRemoteId,
                            "sort_order": 0,
                        ] as [String: Any])
                    }
                } catch {
                    // Skip
                }
            }
        }
    }

    private func pullCollectionBooks() async throws {
        let records = try await fetchRecords("collection_books")

        for record in records {
            let colRemoteId = record["collection"] as? String ?? ""
            let bookRemoteId = record["book"] as? String ?? ""

            guard let localCol = findCollectionByRemoteId(colRemoteId),
                  let localBook = findBookByRemoteId(bookRemoteId) else { continue }

            if !localCol.books.contains(where: { $0.id == localBook.id }) {
                localCol.books.append(localBook)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Helpers

    private func fetchRecords(_ collection: String) async throws -> [[String: Any]] {
        if let lastSync = lastSyncAt {
            let filter = "updated >= \"\(isoString(lastSync))\""
            return try await pb.getFullList(collection: collection, filter: filter)
        }
        return try await pb.getFullList(collection: collection)
    }

    private func findBookByRemoteId(_ remoteId: String) -> MokuBook? {
        let descriptor = FetchDescriptor<MokuBook>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func findBookByHash(_ hash: String) -> MokuBook? {
        let descriptor = FetchDescriptor<MokuBook>(
            predicate: #Predicate { $0.fileHash == hash }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func findProgressByRemoteId(_ remoteId: String) -> ReadingProgress? {
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func findCollectionByRemoteId(_ remoteId: String) -> BookCollection? {
        let descriptor = FetchDescriptor<BookCollection>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func bookToMap(_ book: MokuBook, userId: String) -> [String: String] {
        [
            "title": book.title,
            "author": book.author,
            "description": book.bookDescription ?? "",
            "isbn": book.isbn ?? "",
            "language": book.language ?? "",
            "publisher": book.publisher ?? "",
            "publish_date": book.publishDate.map { isoString($0) } ?? "",
            "total_chapters": "\(book.totalChapters)",
            "file_hash": book.fileHash ?? "",
            "format": book.format,
            "user": userId,
        ]
    }

    private func updateBookFromRecord(_ book: MokuBook, record: [String: Any]) {
        book.title = record["title"] as? String ?? book.title
        book.author = record["author"] as? String ?? book.author
        book.bookDescription = record["description"] as? String
        book.isbn = record["isbn"] as? String
        book.language = record["language"] as? String
        book.publisher = record["publisher"] as? String
        if let dateStr = record["publish_date"] as? String, !dateStr.isEmpty {
            book.publishDate = parseDate(dateStr)
        }
        book.totalChapters = record["total_chapters"] as? Int ?? book.totalChapters
        book.fileHash = record["file_hash"] as? String ?? book.fileHash
        if let fmt = record["format"] as? String, !fmt.isEmpty {
            book.format = fmt
        }
        book.updatedAt = Date()
        try? modelContext.save()
    }

    private func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        // PocketBase sometimes returns dates without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: str) { return d }
        // Also try space-separated format PocketBase uses
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
        if let d = df.date(from: str) { return d }
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.date(from: str)
    }
}
