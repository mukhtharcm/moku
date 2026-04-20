import Foundation
import CryptoKit

/// Generic chapter info — format-agnostic.
struct ChapterInfo: Identifiable {
    let index: Int
    let title: String
    let fileName: String
    let fragment: String?

    var id: Int { index }

    init(index: Int, title: String, fileName: String = "", fragment: String? = nil) {
        self.index = index
        self.title = title
        self.fileName = fileName
        self.fragment = fragment
    }
}

/// Unified service that delegates to format-specific parsers.
@MainActor
@Observable
final class BookService {
    private let epubService = EpubService()

    static func booksDirectory() -> URL {
        EpubService.booksDirectory()
    }

    // MARK: - Import

    func importBook(from url: URL) throws -> MokuBook {
        let ext = url.pathExtension.lowercased()
        let format = BookFormat.from(extension: ext)

        switch format {
        case .epub:
            return try epubService.importEpub(from: url)
        case .pdf:
            return try importGeneric(from: url, format: .pdf, metadataExtractor: { fileURL in
                let meta = PdfParser.extractMetadata(from: fileURL)
                return (
                    title: meta.title ?? fileURL.deletingPathExtension().lastPathComponent,
                    author: meta.author ?? "Unknown",
                    description: meta.subject,
                    totalChapters: meta.pageCount,
                    coverData: nil
                )
            })
        case .txt:
            return try importGeneric(from: url, format: .txt, metadataExtractor: { fileURL in
                let meta = TxtParser.extractMetadata(from: fileURL)
                return (title: meta.title, author: meta.author, description: nil, totalChapters: meta.chapterCount, coverData: nil)
            })
        case .cbz:
            return try importCbz(from: url)
        case .html:
            return try importGeneric(from: url, format: .html, metadataExtractor: { fileURL in
                let meta = HtmlParser.extractMetadata(from: fileURL)
                return (title: meta.title, author: meta.author, description: nil, totalChapters: meta.chapterCount, coverData: nil)
            })
        }
    }

    // MARK: - Chapters

    func getChapters(book: MokuBook) throws -> [ChapterInfo] {
        guard let filePath = book.filePath else { return [] }
        let booksDir = Self.booksDirectory()

        switch book.bookFormat {
        case .epub:
            return try epubService.getChapters(filePath: filePath).map {
                ChapterInfo(index: $0.index, title: $0.title, fileName: $0.fileName, fragment: $0.fragment)
            }
        case .pdf:
            let url = booksDir.appendingPathComponent(filePath)
            return PdfParser.getChapters(from: url)
        case .txt:
            return try TxtParser.getChapters(filePath: filePath, booksDir: booksDir)
        case .cbz:
            return try CbzParser.getChapters(filePath: filePath, booksDir: booksDir)
        case .html:
            return try HtmlParser.getChapters(filePath: filePath, booksDir: booksDir)
        }
    }

    /// Get HTML content for text-based formats (epub, txt, html).
    func getChapterContent(book: MokuBook, chapterIndex: Int) throws -> String {
        guard let filePath = book.filePath else { return "" }
        let booksDir = Self.booksDirectory()

        switch book.bookFormat {
        case .epub:
            return try epubService.getChapterContent(filePath: filePath, chapterIndex: chapterIndex)
        case .txt:
            return try TxtParser.getChapterContent(filePath: filePath, chapterIndex: chapterIndex, booksDir: booksDir)
        case .html:
            return try HtmlParser.getChapterContent(filePath: filePath, chapterIndex: chapterIndex, booksDir: booksDir)
        case .pdf, .cbz:
            return "" // These formats use native renderers
        }
    }

    func closeBook(_ book: MokuBook) {
        guard let filePath = book.filePath else { return }
        switch book.bookFormat {
        case .epub: epubService.closeBook(filePath: filePath)
        case .txt: TxtParser.clearCache(filePath)
        case .html: HtmlParser.clearCache(filePath)
        case .cbz: CbzParser.clearCache(filePath)
        case .pdf: break
        }
    }

    // MARK: - Private import helpers

    private typealias MetadataResult = (title: String, author: String, description: String?, totalChapters: Int, coverData: Data?)

    private func importGeneric(
        from url: URL,
        format: BookFormat,
        metadataExtractor: (URL) -> MetadataResult
    ) throws -> MokuBook {
        let data = try Data(contentsOf: url)
        let bookId = UUID().uuidString
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        let booksDir = Self.booksDirectory()
        try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
        let ext = url.pathExtension.lowercased()
        let destURL = booksDir.appendingPathComponent("\(bookId).\(ext)")
        try data.write(to: destURL)

        let meta = metadataExtractor(destURL)

        var coverRelPath: String?
        if let coverData = meta.coverData {
            let coversDir = booksDir.appendingPathComponent("covers")
            try FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
            let coverURL = coversDir.appendingPathComponent("\(bookId).jpg")
            try coverData.write(to: coverURL)
            coverRelPath = "covers/\(bookId).jpg"
        }

        return MokuBook(
            id: bookId,
            title: meta.title,
            author: meta.author,
            bookDescription: meta.description,
            coverPath: coverRelPath,
            filePath: "\(bookId).\(ext)",
            format: format,
            totalChapters: meta.totalChapters,
            fileHash: hash
        )
    }

    private func importCbz(from url: URL) throws -> MokuBook {
        let data = try Data(contentsOf: url)
        let bookId = UUID().uuidString
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        let booksDir = Self.booksDirectory()
        try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
        let destURL = booksDir.appendingPathComponent("\(bookId).cbz")
        try data.write(to: destURL)

        let meta = CbzParser.extractMetadata(from: destURL)

        // Extract cover
        var coverRelPath: String?
        if let coverData = CbzParser.extractCover(from: destURL) {
            let coversDir = booksDir.appendingPathComponent("covers")
            try FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
            let coverURL = coversDir.appendingPathComponent("\(bookId).jpg")
            try coverData.write(to: coverURL)
            coverRelPath = "covers/\(bookId).jpg"
        }

        return MokuBook(
            id: bookId,
            title: meta.title,
            author: meta.author,
            coverPath: coverRelPath,
            filePath: "\(bookId).cbz",
            format: .cbz,
            totalChapters: meta.pageCount,
            fileHash: hash
        )
    }
}
