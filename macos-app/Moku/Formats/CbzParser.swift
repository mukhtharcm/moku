import Foundation
import ZIPFoundation

/// Parses CBZ (Comic Book ZIP) archives — extracts sorted image pages.
enum CbzParser {

    struct CbzMetadata {
        let title: String
        let author: String
        let pageCount: Int
    }

    // MARK: - Cache

    private nonisolated(unsafe) static var archiveCache: [String: Archive] = [:]
    private nonisolated(unsafe) static var sortedEntries: [String: [Entry]] = [:]

    static func clearCache(_ key: String) {
        archiveCache.removeValue(forKey: key)
        sortedEntries.removeValue(forKey: key)
    }

    // MARK: - Metadata

    static func extractMetadata(from url: URL) -> CbzMetadata {
        let title = url.deletingPathExtension().lastPathComponent
        guard let archive = try? Archive(url: url, accessMode: .read) else {
            return CbzMetadata(title: title, author: "Unknown", pageCount: 0)
        }
        let images = imageEntries(from: archive)
        return CbzMetadata(title: title, author: "Unknown", pageCount: images.count)
    }

    // MARK: - Chapters (pages)

    static func getChapters(filePath: String, booksDir: URL) throws -> [ChapterInfo] {
        let entries = try loadOrCache(filePath: filePath, booksDir: booksDir)
        return entries.enumerated().map { (i, entry) in
            let name = (entry.path as NSString).lastPathComponent
            return ChapterInfo(index: i, title: "Page \(i + 1) — \(name)")
        }
    }

    static func getPageCount(filePath: String, booksDir: URL) throws -> Int {
        try loadOrCache(filePath: filePath, booksDir: booksDir).count
    }

    /// Get image data for a specific page.
    static func getPageImage(filePath: String, pageIndex: Int, booksDir: URL) throws -> Data? {
        let entries = try loadOrCache(filePath: filePath, booksDir: booksDir)
        guard pageIndex >= 0, pageIndex < entries.count else { return nil }

        let url = booksDir.appendingPathComponent(filePath)
        guard let archive = try? Archive(url: url, accessMode: .read) else { return nil }

        let entry = entries[pageIndex]
        var imageData = Data()
        _ = try archive.extract(entry) { chunk in
            imageData.append(chunk)
        }
        return imageData
    }

    /// Extract cover (first image) data.
    static func extractCover(from url: URL) -> Data? {
        guard let archive = try? Archive(url: url, accessMode: .read) else { return nil }
        let images = imageEntries(from: archive)
        guard let first = images.first else { return nil }
        var data = Data()
        _ = try? archive.extract(first) { chunk in data.append(chunk) }
        return data
    }

    // MARK: - Private

    private static func loadOrCache(filePath: String, booksDir: URL) throws -> [Entry] {
        if let cached = sortedEntries[filePath] { return cached }
        let url = booksDir.appendingPathComponent(filePath)
        guard let archive = try? Archive(url: url, accessMode: .read) else {
            throw NSError(domain: "CbzParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open archive"])
        }
        let entries = imageEntries(from: archive)
        sortedEntries[filePath] = entries
        return entries
    }

    private static func imageEntries(from archive: Archive) -> [Entry] {
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"]

        return archive
            .filter { entry in
                guard entry.type == .file else { return false }
                let path = entry.path
                // Skip macOS metadata
                if path.contains("__MACOSX") || path.contains(".DS_Store") { return false }
                let name = (path as NSString).lastPathComponent
                if name.hasPrefix(".") { return false }
                let ext = (name as NSString).pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }
            .sorted { naturalSort($0.path, $1.path) }
    }

    /// Natural sort: "page2" < "page10"
    private static func naturalSort(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.numeric, .caseInsensitive]) == .orderedAscending
    }
}
