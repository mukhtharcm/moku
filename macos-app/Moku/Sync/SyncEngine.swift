import Foundation
import SwiftData
import CryptoKit

/// Outcome of a sync run. Mirrors the Flutter `SyncResult`.
struct SyncResult {
    /// Non-nil only when every collection synced successfully; this is what
    /// callers persist as `lastSyncAt` so partial failures get retried.
    let syncedAt: Date?
    let failedCollections: [String]
    let authFailed: Bool
    let skippedAlreadyRunning: Bool

    var isFullSuccess: Bool {
        syncedAt != nil && failedCollections.isEmpty && !authFailed
    }

    static let alreadyRunning = SyncResult(
        syncedAt: nil, failedCollections: [], authFailed: false,
        skippedAlreadyRunning: true)
}

/// Bidirectional PocketBase sync engine for the macOS app.
/// Follows the same protocol as the Flutter sync engine:
/// Books → ReadingProgress → Bookmarks → Highlights → Collections → CollectionBooks
@MainActor
final class SyncEngine {
    let pb: PocketBaseClient
    let modelContext: ModelContext
    private var lastSyncAt: Date?

    private var isSyncing = false
    var onError: ((String, String) -> Void)?

    init(pb: PocketBaseClient, modelContext: ModelContext) {
        self.pb = pb
        self.modelContext = modelContext
    }

    /// Run a full bidirectional sync. Returns a [SyncResult] describing the
    /// outcome. `syncedAt` is only set when every collection succeeded so the
    /// cursor advances only on full success.
    func syncAll(lastSyncAt: Date? = nil) async throws -> SyncResult {
        guard !isSyncing else {
            print("[SyncEngine] Sync already in progress, skipping")
            return .alreadyRunning
        }
        isSyncing = true
        defer { isSyncing = false }

        self.lastSyncAt = lastSyncAt
        let syncTime = Date()
        var failed: [String] = []
        var authFailed = false

        // Refresh auth token before sync
        do {
            try await pb.refreshAuth()
        } catch {
            print("[SyncEngine] Auth refresh failed: \(error)")
            if !pb.isAuthenticated {
                authFailed = true
                return SyncResult(syncedAt: nil, failedCollections: [],
                                  authFailed: true,
                                  skippedAlreadyRunning: false)
            }
        }

        func run(_ name: String, _ op: () async throws -> Void) async {
            do { try await op() } catch {
                print("[SyncEngine] \(name) sync failed: \(error)")
                failed.append(name)
                onError?(name, "\(error)")
            }
        }

        await run("books", syncBooks)
        await run("reading_progress", syncReadingProgress)
        await run("bookmarks", syncBookmarks)
        await run("highlights", syncHighlights)
        await run("collections", syncCollections)
        await run("collection_books", syncCollectionBooks)
        await run("reading_sessions", syncReadingSessions)
        await run("reading_goals", syncReadingGoals)

        // Advance cursor only on full success.
        let resolvedSyncedAt = failed.isEmpty ? syncTime : nil
        return SyncResult(
            syncedAt: resolvedSyncedAt,
            failedCollections: failed,
            authFailed: authFailed,
            skippedAlreadyRunning: false
        )
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
                    updateBookFromRecord(existing, record: record, remoteUpdated: remoteUpdated)
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
                        existing.lastReadAt = parseDate(lastReadStr) ?? remoteUpdated
                    }
                    existing.updatedAt = remoteUpdated
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
                    existing.updatedAt = remoteUpdated
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
                    existing.updatedAt = remoteUpdated
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
            _ = record["sort_order"] as? Int ?? 0

            guard let localCol = findCollectionByRemoteId(colRemoteId),
                  let localBook = findBookByRemoteId(bookRemoteId) else { continue }

            if !localCol.books.contains(where: { $0.id == localBook.id }) {
                localCol.books.append(localBook)
                try? modelContext.save()
            }
            // TODO: Reordering based on sort_order requires a custom data structure.
            // For now we preserve server order by appending in the order received.
        }
    }

    // MARK: - Reading Sessions

    private func syncReadingSessions() async throws {
        try await pushReadingSessions()
        try await pullReadingSessions()
    }

    private func pushReadingSessions() async throws {
        guard let userId = pb.userId else { return }
        let sessions = try modelContext.fetch(FetchDescriptor<ReadingSession>())

        for session in sessions where session.remoteId == nil {
            guard let bookRemoteId = session.book?.remoteId else { continue }
            do {
                var body: [String: Any] = [
                    "book": bookRemoteId,
                    "user": userId,
                    "book_title": session.bookTitle,
                    "started_at": isoString(session.startedAt),
                    "duration_seconds": session.durationSeconds,
                    "start_chapter": session.startChapter,
                    "end_chapter": session.endChapter,
                ]
                if let endedAt = session.endedAt {
                    body["ended_at"] = isoString(endedAt)
                }
                let record = try await pb.create(collection: "reading_sessions", body: body)
                session.remoteId = record["id"] as? String
                try? modelContext.save()
            } catch {
                // Skip
            }
        }
    }

    private func pullReadingSessions() async throws {
        let records = try await fetchRecords("reading_sessions")
        for record in records {
            let remoteId = record["id"] as? String ?? ""
            // Skip if already imported by remoteId
            let descriptor = FetchDescriptor<ReadingSession>(
                predicate: #Predicate { $0.remoteId == remoteId }
            )
            if (try? modelContext.fetch(descriptor).first) != nil { continue }

            let bookRemoteId = record["book"] as? String ?? ""
            let localBook = findBookByRemoteId(bookRemoteId)
            let startedAt = (record["started_at"] as? String).flatMap { parseDate($0) } ?? Date()

            // Duplicate guard: skip if a session for same book started within ±60 s
            if let localBook {
                let bookId = localBook.id
                let windowStart = startedAt.addingTimeInterval(-60)
                let windowEnd = startedAt.addingTimeInterval(60)
                let dupDescriptor = FetchDescriptor<ReadingSession>(
                    predicate: #Predicate { s in
                        s.book?.id == bookId && s.startedAt >= windowStart && s.startedAt <= windowEnd
                    }
                )
                if (try? modelContext.fetch(dupDescriptor).first) != nil { continue }
            }

            let endedAt = (record["ended_at"] as? String).flatMap { parseDate($0) }
            let session = ReadingSession(
                id: "rs_\(String(remoteId.prefix(11)))",
                book: localBook,
                bookTitle: localBook?.title ?? (record["book_title"] as? String ?? ""),
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: record["duration_seconds"] as? Int ?? 0,
                startChapter: record["start_chapter"] as? Int ?? 0,
                endChapter: record["end_chapter"] as? Int ?? 0,
                remoteId: remoteId
            )
            modelContext.insert(session)
            try? modelContext.save()
        }
    }

    // MARK: - Reading Goals

    private func syncReadingGoals() async throws {
        try await pushReadingGoals()
        try await pullReadingGoals()
    }

    private func pushReadingGoals() async throws {
        guard let userId = pb.userId else { return }
        let goals = try modelContext.fetch(FetchDescriptor<ReadingGoal>())

        // Push new goals
        for goal in goals where goal.remoteId == nil {
            do {
                let record = try await pb.create(collection: "reading_goals", body: [
                    "user": userId,
                    "year": goal.year,
                    "books_goal": goal.booksGoal,
                    "minutes_per_day_goal": goal.minutesPerDayGoal,
                ] as [String: Any])
                goal.remoteId = record["id"] as? String
                try? modelContext.save()
            } catch {
                // Skip
            }
        }

        // Push updates for existing goals (always push — goals are small)
        for goal in goals where goal.remoteId != nil {
            do {
                _ = try await pb.update(collection: "reading_goals", id: goal.remoteId!, body: [
                    "year": goal.year,
                    "books_goal": goal.booksGoal,
                    "minutes_per_day_goal": goal.minutesPerDayGoal,
                ] as [String: Any])
            } catch {
                // Skip
            }
        }
    }

    private func pullReadingGoals() async throws {
        let records = try await fetchRecords("reading_goals")
        for record in records {
            let remoteId = record["id"] as? String ?? ""
            let descriptor = FetchDescriptor<ReadingGoal>(
                predicate: #Predicate { $0.remoteId == remoteId }
            )
            if (try? modelContext.fetch(descriptor).first) != nil { continue }

            let goal = ReadingGoal(
                id: "rg_\(String(remoteId.prefix(11)))",
                year: record["year"] as? Int ?? Calendar.current.component(.year, from: Date()),
                booksGoal: record["books_goal"] as? Int ?? 12,
                minutesPerDayGoal: record["minutes_per_day_goal"] as? Int ?? 30,
                remoteId: remoteId
            )
            modelContext.insert(goal)
            try? modelContext.save()
        }
    }

    // MARK: - Deletion helpers

    func deleteBook(_ book: MokuBook) async {
        if let remoteId = book.remoteId {
            do {
                try await pb.delete(collection: "books", id: remoteId)
            } catch {
                print("[SyncEngine] Remote book delete failed: \(error)")
            }
        }
        if let filePath = book.filePath {
            let fullPath = BookService.booksDirectory().appendingPathComponent(filePath)
            try? FileManager.default.removeItem(at: fullPath)
        }
        if let coverPath = book.coverPath {
            let fullCover = BookService.booksDirectory().appendingPathComponent(coverPath)
            try? FileManager.default.removeItem(at: fullCover)
        }
        modelContext.delete(book)
        try? modelContext.save()
    }

    func deleteCollection(_ collection: BookCollection) async {
        if let remoteId = collection.remoteId {
            do {
                try await pb.delete(collection: "collections", id: remoteId)
            } catch {
                print("[SyncEngine] Remote collection delete failed: \(error)")
            }
        }
        modelContext.delete(collection)
        try? modelContext.save()
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

    private func bookToMap(_ book: MokuBook, userId: String) -> [String: Any] {
        [
            "title": book.title,
            "author": book.author,
            "description": book.bookDescription ?? "",
            "isbn": book.isbn ?? "",
            "language": book.language ?? "",
            "publisher": book.publisher ?? "",
            "publish_date": book.publishDate.map { isoString($0) } ?? "",
            "total_chapters": book.totalChapters,
            "file_hash": book.fileHash ?? "",
            "format": book.bookFormat.rawValue,
            "user": userId,
        ]
    }

    private func updateBookFromRecord(_ book: MokuBook, record: [String: Any], remoteUpdated: Date) {
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
        book.updatedAt = remoteUpdated
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
