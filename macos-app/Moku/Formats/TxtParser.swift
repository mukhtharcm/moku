import Foundation

/// Parses plain-text files into chapters for WebView rendering.
enum TxtParser {

    struct TxtMetadata {
        let title: String
        let author: String
        let chapterCount: Int
    }

    struct TxtChapter {
        let index: Int
        let title: String
        let content: String // HTML
    }

    // MARK: - Cache

    private nonisolated(unsafe) static var cache: [String: [TxtChapter]] = [:]

    static func clearCache(_ key: String) {
        cache.removeValue(forKey: key)
    }

    // MARK: - Metadata

    static func extractMetadata(from url: URL) -> TxtMetadata {
        let title = url.deletingPathExtension().lastPathComponent
        let chapters = (try? parseChapters(from: url)) ?? []
        return TxtMetadata(title: title, author: "Unknown", chapterCount: chapters.count)
    }

    // MARK: - Chapters

    static func getChapters(filePath: String, booksDir: URL) throws -> [ChapterInfo] {
        let chapters = try loadOrCache(filePath: filePath, booksDir: booksDir)
        return chapters.map { ChapterInfo(index: $0.index, title: $0.title) }
    }

    static func getChapterContent(filePath: String, chapterIndex: Int, booksDir: URL) throws -> String {
        let chapters = try loadOrCache(filePath: filePath, booksDir: booksDir)
        guard chapterIndex >= 0, chapterIndex < chapters.count else { return "" }
        return chapters[chapterIndex].content
    }

    // MARK: - Private

    private static func loadOrCache(filePath: String, booksDir: URL) throws -> [TxtChapter] {
        if let cached = cache[filePath] { return cached }
        let url = booksDir.appendingPathComponent(filePath)
        let chapters = try parseChapters(from: url)
        cache[filePath] = chapters
        return chapters
    }

    private static func parseChapters(from url: URL) throws -> [TxtChapter] {
        let data = try Data(contentsOf: url)
        let text: String
        if let utf8 = String(data: data, encoding: .utf8) {
            text = utf8
        } else if let latin = String(data: data, encoding: .isoLatin1) {
            text = latin
        } else {
            text = String(decoding: data, as: UTF8.self)
        }

        let lines = text.components(separatedBy: .newlines)

        // Detect chapter boundaries
        let chapterPattern = try NSRegularExpression(
            pattern: #"^(?:CHAPTER|Chapter|PART|Part|BOOK|Book)\s+[\dIVXLCDMivxlcdm]+"#,
            options: []
        )
        let dividerPattern = try NSRegularExpression(
            pattern: #"^[\s]*[*\-=]{3,}[\s]*$"#,
            options: []
        )

        var boundaries: [Int] = [0]
        for (i, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                if chapterPattern.firstMatch(in: line, range: range) != nil {
                    if i > 0 { boundaries.append(i) }
                } else if dividerPattern.firstMatch(in: line, range: range) != nil {
                    if i > 0 && i < lines.count - 1 { boundaries.append(i) }
                }
            }
        }

        // If no chapter markers found, split into ~3000-line chunks
        if boundaries.count <= 1 {
            boundaries = [0]
            let chunkSize = 3000
            var pos = chunkSize
            while pos < lines.count {
                boundaries.append(pos)
                pos += chunkSize
            }
        }

        // Build chapters
        var chapters: [TxtChapter] = []
        for (i, start) in boundaries.enumerated() {
            let end = i + 1 < boundaries.count ? boundaries[i + 1] : lines.count
            let chapterLines = Array(lines[start..<end])

            let title: String
            let firstNonEmpty = chapterLines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if let first = firstNonEmpty, first.count < 80 {
                title = first.trimmingCharacters(in: .whitespaces)
            } else {
                title = "Section \(i + 1)"
            }

            let html = textToHTML(chapterLines)
            chapters.append(TxtChapter(index: i, title: title, content: html))
        }

        return chapters.isEmpty ? [TxtChapter(index: 0, title: "Text", content: textToHTML(lines))] : chapters
    }

    private static func textToHTML(_ lines: [String]) -> String {
        var html = ""
        var paragraph = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !paragraph.isEmpty {
                    html += "<p>\(escapeHTML(paragraph))</p>\n"
                    paragraph = ""
                }
            } else {
                if !paragraph.isEmpty { paragraph += " " }
                paragraph += trimmed
            }
        }
        if !paragraph.isEmpty {
            html += "<p>\(escapeHTML(paragraph))</p>\n"
        }

        return html
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
