import Foundation
import SwiftData

/// Supported book formats
enum BookFormat: String, Codable, CaseIterable {
    case epub
    case pdf
    case txt
    case cbz
    case html

    var displayName: String {
        switch self {
        case .epub: "EPUB"
        case .pdf: "PDF"
        case .txt: "TXT"
        case .cbz: "CBZ"
        case .html: "HTML"
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .epub: ["epub"]
        case .pdf: ["pdf"]
        case .txt: ["txt"]
        case .cbz: ["cbz", "cbr"]
        case .html: ["html", "htm"]
        }
    }

    static var allExtensions: [String] {
        allCases.flatMap(\.fileExtensions)
    }

    static func from(extension ext: String) -> BookFormat {
        let lower = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        for format in allCases {
            if format.fileExtensions.contains(lower) { return format }
        }
        return .epub
    }
}

@Model
final class MokuBook {
    @Attribute(.unique) var id: String
    var title: String
    var author: String
    var bookDescription: String?
    var coverPath: String?
    var filePath: String?
    var format: String?
    var isbn: String?
    var language: String?
    var publisher: String?
    var publishDate: Date?
    var totalChapters: Int
    var fileHash: String?
    var createdAt: Date
    var updatedAt: Date
    var remoteId: String?

    @Relationship(deleteRule: .cascade, inverse: \ReadingProgress.book)
    var readingProgress: ReadingProgress?

    @Relationship(deleteRule: .cascade, inverse: \BookmarkItem.book)
    var bookmarks: [BookmarkItem]

    @Relationship(deleteRule: .cascade, inverse: \Highlight.book)
    var highlights: [Highlight]

    @Relationship(inverse: \BookCollection.books)
    var collections: [BookCollection]

    var bookFormat: BookFormat {
        get {
            if let format, let parsed = BookFormat(rawValue: format) {
                return parsed
            }
            if let filePath {
                let ext = URL(fileURLWithPath: filePath).pathExtension
                if !ext.isEmpty {
                    return BookFormat.from(extension: ext)
                }
            }
            return .epub
        }
        set { format = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String,
        bookDescription: String? = nil,
        coverPath: String? = nil,
        filePath: String? = nil,
        format: BookFormat = .epub,
        isbn: String? = nil,
        language: String? = nil,
        publisher: String? = nil,
        publishDate: Date? = nil,
        totalChapters: Int = 0,
        fileHash: String? = nil,
        remoteId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.bookDescription = bookDescription
        self.coverPath = coverPath
        self.filePath = filePath
        self.format = format.rawValue
        self.isbn = isbn
        self.language = language
        self.publisher = publisher
        self.publishDate = publishDate
        self.totalChapters = totalChapters
        self.fileHash = fileHash
        self.createdAt = Date()
        self.updatedAt = Date()
        self.remoteId = remoteId
        self.bookmarks = []
        self.highlights = []
        self.collections = []
    }
}

@Model
final class ReadingProgress {
    @Attribute(.unique) var id: String
    var book: MokuBook?
    var currentChapter: Int
    var chapterProgress: Double
    var overallProgress: Double
    var lastPosition: String?
    var lastReadAt: Date
    var updatedAt: Date
    var remoteId: String?

    init(
        id: String = UUID().uuidString,
        book: MokuBook? = nil,
        currentChapter: Int = 0,
        chapterProgress: Double = 0.0,
        overallProgress: Double = 0.0,
        lastPosition: String? = nil,
        remoteId: String? = nil
    ) {
        self.id = id
        self.book = book
        self.currentChapter = currentChapter
        self.chapterProgress = chapterProgress
        self.overallProgress = overallProgress
        self.lastPosition = lastPosition
        self.lastReadAt = Date()
        self.updatedAt = Date()
        self.remoteId = remoteId
    }
}

@Model
final class BookmarkItem {
    @Attribute(.unique) var id: String
    var book: MokuBook?
    var chapterIndex: Int
    var cfi: String?
    var title: String
    var createdAt: Date
    var remoteId: String?

    init(
        id: String = UUID().uuidString,
        book: MokuBook? = nil,
        chapterIndex: Int = 0,
        cfi: String? = nil,
        title: String = "Bookmark",
        remoteId: String? = nil
    ) {
        self.id = id
        self.book = book
        self.chapterIndex = chapterIndex
        self.cfi = cfi
        self.title = title
        self.createdAt = Date()
        self.remoteId = remoteId
    }
}

@Model
final class Highlight {
    @Attribute(.unique) var id: String
    var book: MokuBook?
    var chapterIndex: Int
    var startCfi: String?
    var endCfi: String?
    var selectedText: String
    var color: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var remoteId: String?

    init(
        id: String = UUID().uuidString,
        book: MokuBook? = nil,
        chapterIndex: Int = 0,
        startCfi: String? = nil,
        endCfi: String? = nil,
        selectedText: String = "",
        color: String = "#FFEB3B",
        note: String? = nil,
        remoteId: String? = nil
    ) {
        self.id = id
        self.book = book
        self.chapterIndex = chapterIndex
        self.startCfi = startCfi
        self.endCfi = endCfi
        self.selectedText = selectedText
        self.color = color
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
        self.remoteId = remoteId
    }
}

@Model
final class BookCollection {
    @Attribute(.unique) var id: String
    var name: String
    var collectionDescription: String?
    var coverPath: String?
    var createdAt: Date
    var updatedAt: Date
    var remoteId: String?

    var books: [MokuBook]

    init(
        id: String = UUID().uuidString,
        name: String,
        collectionDescription: String? = nil,
        coverPath: String? = nil,
        remoteId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.collectionDescription = collectionDescription
        self.coverPath = coverPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.remoteId = remoteId
        self.books = []
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
