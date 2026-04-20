import Foundation

/// Parses HTML files into chapters for WebView rendering.
enum HtmlParser {

    struct HtmlMetadata {
        let title: String
        let author: String
        let chapterCount: Int
    }

    struct HtmlChapter {
        let index: Int
        let title: String
        let content: String // raw HTML body content
    }

    // MARK: - Cache

    private nonisolated(unsafe) static var cache: [String: [HtmlChapter]] = [:]

    static func clearCache(_ key: String) {
        cache.removeValue(forKey: key)
    }

    // MARK: - Metadata

    static func extractMetadata(from url: URL) -> HtmlMetadata {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return HtmlMetadata(
                title: url.deletingPathExtension().lastPathComponent,
                author: "Unknown",
                chapterCount: 1
            )
        }

        let title = extractTag(from: text, tag: "title")
            ?? url.deletingPathExtension().lastPathComponent
        let author = extractMetaContent(from: text, name: "author") ?? "Unknown"
        let chapters = splitByHeadings(text)
        return HtmlMetadata(title: title, author: author, chapterCount: chapters.count)
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

    private static func loadOrCache(filePath: String, booksDir: URL) throws -> [HtmlChapter] {
        if let cached = cache[filePath] { return cached }
        let url = booksDir.appendingPathComponent(filePath)
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            return [HtmlChapter(index: 0, title: "Document", content: String(decoding: data, as: UTF8.self))]
        }
        let chapters = splitByHeadings(text)
        cache[filePath] = chapters
        return chapters
    }

    private static func splitByHeadings(_ html: String) -> [HtmlChapter] {
        // Extract body content if present
        let body: String
        if let bodyRange = html.range(of: "<body", options: .caseInsensitive),
           let closeTag = html[bodyRange.upperBound...].range(of: ">"),
           let endBody = html.range(of: "</body>", options: .caseInsensitive) {
            body = String(html[closeTag.upperBound..<endBody.lowerBound])
        } else {
            body = html
        }

        // Split by <h1> or <h2> tags
        let pattern = try! NSRegularExpression(
            pattern: #"<h[12][^>]*>(.*?)</h[12]>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        let matches = pattern.matches(in: body, range: NSRange(body.startIndex..., in: body))

        guard !matches.isEmpty else {
            return [HtmlChapter(index: 0, title: "Document", content: body)]
        }

        var chapters: [HtmlChapter] = []
        for (i, match) in matches.enumerated() {
            let titleRange = Range(match.range(at: 1), in: body)!
            let title = String(body[titleRange])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let start = Range(match.range, in: body)!.lowerBound
            let end: String.Index
            if i + 1 < matches.count {
                end = Range(matches[i + 1].range, in: body)!.lowerBound
            } else {
                end = body.endIndex
            }
            let content = String(body[start..<end])
            chapters.append(HtmlChapter(index: i, title: title.isEmpty ? "Section \(i+1)" : title, content: content))
        }

        // If there's content before the first heading, prepend it
        let firstMatchStart = Range(matches[0].range, in: body)!.lowerBound
        let prefix = body[body.startIndex..<firstMatchStart].trimmingCharacters(in: .whitespacesAndNewlines)
        if !prefix.isEmpty {
            chapters.insert(HtmlChapter(index: 0, title: "Introduction", content: prefix), at: 0)
            // Re-index
            chapters = chapters.enumerated().map { (i, ch) in
                HtmlChapter(index: i, title: ch.title, content: ch.content)
            }
        }

        return chapters.isEmpty ? [HtmlChapter(index: 0, title: "Document", content: body)] : chapters
    }

    private static func extractTag(from html: String, tag: String) -> String? {
        let pattern = try! NSRegularExpression(
            pattern: "<\(tag)[^>]*>(.*?)</\(tag)>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        guard let match = pattern.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let value = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = try! NSRegularExpression(
            pattern: #"<meta\s+name\s*=\s*"\#(name)"\s+content\s*=\s*"([^"]*)""#,
            options: .caseInsensitive
        )
        guard let match = pattern.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let value = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
