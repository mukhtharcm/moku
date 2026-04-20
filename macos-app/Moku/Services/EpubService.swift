import Foundation
import SwiftData
import CryptoKit

/// Manages EPUB file operations: importing, caching, and content serving.
@MainActor
@Observable
final class EpubService {
    private var cache: [String: (document: EpubDocument, server: EpubContentServer)] = [:]

    /// Import an EPUB file and create a Book model.
    func importEpub(from url: URL) throws -> MokuBook {
        let data = try Data(contentsOf: url)
        let document = try EpubParser.parse(data: data)
        let server = EpubContentServer(document: document)

        // Generate stable ID
        let bookId = UUID().uuidString

        // Compute file hash for dedup
        let hash = SHA256.hash(data: data)
        let fileHash = hash.map { String(format: "%02x", $0) }.joined()

        // Copy EPUB to app support
        let booksDir = Self.booksDirectory()
        try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
        let destURL = booksDir.appendingPathComponent("\(bookId).epub")
        try data.write(to: destURL)

        // Extract and save cover
        var coverRelPath: String?
        if let cover = server.getCoverImage() {
            let coversDir = booksDir.appendingPathComponent("covers")
            try FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)

            let ext: String
            switch cover.mediaType {
            case "image/png": ext = "png"
            case "image/gif": ext = "gif"
            case "image/webp": ext = "webp"
            default: ext = "jpg"
            }
            let coverURL = coversDir.appendingPathComponent("\(bookId).\(ext)")
            try cover.data.write(to: coverURL)
            coverRelPath = "covers/\(bookId).\(ext)"
        }

        // Cache the parsed data
        let relPath = "\(bookId).epub"
        cache[relPath] = (document, server)

        let meta = document.metadata
        let book = MokuBook(
            id: bookId,
            title: meta.title,
            author: meta.authors.joined(separator: ", "),
            bookDescription: meta.description,
            coverPath: coverRelPath,
            filePath: relPath,
            isbn: meta.isbn,
            language: meta.language,
            publisher: meta.publisher,
            totalChapters: server.chapters.count,
            fileHash: fileHash
        )

        return book
    }

    /// Get chapters for a book.
    func getChapters(filePath: String) throws -> [EpubChapterInfo] {
        let server = try loadOrCache(filePath: filePath)
        return server.chapters.map { ch in
            EpubChapterInfo(
                index: ch.index,
                title: ch.title,
                fileName: ch.contentHref,
                fragment: ch.fragment
            )
        }
    }

    /// Get rendered HTML content for a chapter.
    func getChapterContent(filePath: String, chapterIndex: Int) throws -> String {
        let server = try loadOrCache(filePath: filePath)
        return server.getChapterContent(chapterIndex)
    }

    /// Get total number of chapters.
    func getTotalChapters(filePath: String) throws -> Int {
        let server = try loadOrCache(filePath: filePath)
        return server.chapters.count
    }

    /// Close a book and free memory.
    func closeBook(filePath: String) {
        cache.removeValue(forKey: filePath)
    }

    // MARK: - Private

    private func loadOrCache(filePath: String) throws -> EpubContentServer {
        if let cached = cache[filePath] {
            return cached.server
        }

        let fullURL = Self.booksDirectory().appendingPathComponent(filePath)
        let data = try Data(contentsOf: fullURL)
        let document = try EpubParser.parse(data: data)
        let server = EpubContentServer(document: document)
        cache[filePath] = (document, server)
        return server
    }

    static func booksDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Moku/books", isDirectory: true)
    }

    /// Resolve a cover path to a full URL.
    static func coverURL(for relativePath: String?) -> URL? {
        guard let path = relativePath else { return nil }
        return booksDirectory().appendingPathComponent(path)
    }
}

struct EpubChapterInfo: Identifiable {
    let index: Int
    let title: String
    let fileName: String
    let fragment: String?

    var id: Int { index }
}
