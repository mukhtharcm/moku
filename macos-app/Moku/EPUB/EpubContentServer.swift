import Foundation

/// Serves rendered chapter content from a parsed EPUB document.
final class EpubContentServer: Sendable {

    let document: EpubDocument
    let chapters: [ReadingChapter]

    private let imageDataURIs: [String: String]   // href → data:URI
    private let combinedCSS: String

    init(document: EpubDocument) {
        self.document = document

        // Pre-build image data URIs
        var uris: [String: String] = [:]
        for item in document.manifest where item.isImage {
            if let resource = document.findResource(href: item.href) {
                let base64 = resource.data.base64EncodedString()
                uris[item.href] = "data:\(resource.mediaType);base64,\(base64)"

                // Also store by basename for flexible matching
                let basename = (item.href as NSString).lastPathComponent
                uris[basename] = uris[item.href]!
            }
        }
        self.imageDataURIs = uris

        // Concatenate all CSS
        var css = ""
        for item in document.manifest where item.isCss {
            if let resource = document.findResource(href: item.href) {
                css += resource.textContent + "\n"
            }
        }
        self.combinedCSS = css

        // Build chapter list
        self.chapters = Self.buildChapters(document: document)
    }

    // MARK: - Chapter Content

    /// Returns an HTML body fragment for the given chapter, with embedded images.
    func getChapterContent(_ index: Int) -> String {
        guard index >= 0, index < chapters.count else {
            return "<p>Chapter not found.</p>"
        }

        let chapter = chapters[index]
        guard let resource = document.findResource(href: chapter.contentHref) else {
            return "<p>Content not available.</p>"
        }

        var html = resource.textContent
        html = extractBodyContent(html)
        html = embedImages(in: html)

        return html
    }

    // MARK: - Cover Image

    /// Returns the cover image media type and data, if available.
    func getCoverImage() -> (mediaType: String, data: Data)? {
        // Check metadata cover manifest ID
        if let coverId = document.metadata.coverManifestId {
            // Try as manifest ID
            if let item = document.manifest.first(where: { $0.id == coverId }),
               let resource = document.findResource(href: item.href)
            {
                return (resource.mediaType, resource.data)
            }
            // Try as direct href
            if let resource = document.findResource(href: coverId) {
                return (resource.mediaType, resource.data)
            }
        }

        // Check manifest for cover-image property
        if let item = document.manifest.first(where: { $0.isCoverImage }),
           let resource = document.findResource(href: item.href)
        {
            return (resource.mediaType, resource.data)
        }

        // Check for item with "cover" in the ID
        if let item = document.manifest.first(where: {
            $0.isImage && $0.id.lowercased().contains("cover")
        }),
           let resource = document.findResource(href: item.href)
        {
            return (resource.mediaType, resource.data)
        }

        return nil
    }

    // MARK: - Chapter Building

    private static func buildChapters(document: EpubDocument) -> [ReadingChapter] {
        let flatToc = document.toc.flatMap { $0.flatten() }
        let spine = document.spine.filter { $0.isLinear }

        if flatToc.isEmpty {
            // No TOC: use spine entries directly
            return spine.enumerated().map { index, entry in
                ReadingChapter(
                    index: index,
                    title: "Chapter \(index + 1)",
                    contentHref: entry.href,
                    fragment: nil
                )
            }
        }

        // Check if this is a single-file (or few-file) EPUB with many TOC entries per spine item
        let tocFileGroups = Dictionary(grouping: flatToc, by: { $0.href })
        let spineItemsWithMultipleTocEntries = spine.filter { entry in
            (tocFileGroups[entry.href]?.count ?? 0) > 1
        }

        let useTocAsChapters = flatToc.count > spine.count && !spineItemsWithMultipleTocEntries.isEmpty

        if useTocAsChapters {
            // Single-file EPUB: each TOC entry is a chapter
            return flatToc.enumerated().map { index, entry in
                ReadingChapter(
                    index: index,
                    title: entry.title,
                    contentHref: entry.href,
                    fragment: entry.fragment
                )
            }
        }

        // Multi-file EPUB: use spine items, assign TOC titles where possible
        let tocByHref = Dictionary(flatToc.map { ($0.href, $0) }, uniquingKeysWith: { a, _ in a })

        return spine.enumerated().map { index, entry in
            let tocEntry = tocByHref[entry.href]
            let title = tocEntry?.title ?? "Chapter \(index + 1)"

            return ReadingChapter(
                index: index,
                title: title,
                contentHref: entry.href,
                fragment: tocEntry?.fragment
            )
        }
    }

    // MARK: - HTML Processing

    /// Replace image src attributes with base64 data URIs.
    private func embedImages(in html: String) -> String {
        // Match src="..." in img tags (and similar elements)
        let pattern = #"(<img[^>]*?\bsrc\s*=\s*["'])([^"']+)(["'])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return html
        }

        let nsHtml = html as NSString
        var result = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))

        // Process in reverse to preserve indices
        for match in matches.reversed() {
            guard match.numberOfRanges >= 4 else { continue }

            let srcRange = match.range(at: 2)
            let src = nsHtml.substring(with: srcRange)

            if let dataURI = resolveImageURI(src) {
                let fullRange = match.range(at: 0)
                let prefix = nsHtml.substring(with: match.range(at: 1))
                let suffix = nsHtml.substring(with: match.range(at: 3))
                let replacement = prefix + dataURI + suffix

                let swiftRange = Range(fullRange, in: result)!
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }

        // Also handle SVG image xlink:href and href
        let svgPattern = #"(<image[^>]*?\b(?:xlink:)?href\s*=\s*["'])([^"']+)(["'])"#
        if let svgRegex = try? NSRegularExpression(pattern: svgPattern, options: [.caseInsensitive]) {
            let nsSvgHtml = result as NSString
            let svgMatches = svgRegex.matches(in: result, range: NSRange(location: 0, length: nsSvgHtml.length))

            for match in svgMatches.reversed() {
                guard match.numberOfRanges >= 4 else { continue }

                let srcRange = match.range(at: 2)
                let src = nsSvgHtml.substring(with: srcRange)

                if let dataURI = resolveImageURI(src) {
                    let fullRange = match.range(at: 0)
                    let prefix = nsSvgHtml.substring(with: match.range(at: 1))
                    let suffix = nsSvgHtml.substring(with: match.range(at: 3))
                    let replacement = prefix + dataURI + suffix

                    let swiftRange = Range(fullRange, in: result)!
                    result.replaceSubrange(swiftRange, with: replacement)
                }
            }
        }

        return result
    }

    /// Resolve an image src to a data URI.
    private func resolveImageURI(_ src: String) -> String? {
        // Already a data URI
        if src.hasPrefix("data:") { return nil }

        let decoded = src.removingPercentEncoding ?? src

        // Try exact match
        if let uri = imageDataURIs[decoded] { return uri }
        if let uri = imageDataURIs[src] { return uri }

        // Try basename
        let basename = (decoded as NSString).lastPathComponent
        if let uri = imageDataURIs[basename] { return uri }

        // Try with OPF directory prefix
        if !document.opfDirectory.isEmpty {
            let prefixed = document.opfDirectory + "/" + decoded
            if let uri = imageDataURIs[prefixed] { return uri }
        }

        // Fallback: find resource and build inline
        if let resource = document.findResource(href: decoded), resource.mediaType.hasPrefix("image/") {
            let base64 = resource.data.base64EncodedString()
            return "data:\(resource.mediaType);base64,\(base64)"
        }

        return nil
    }

    /// Extract the content inside <body>, preserving <style> blocks from <head>.
    private func extractBodyContent(_ html: String) -> String {
        var styles = ""
        var body = html

        // Extract <style> blocks from <head>
        let stylePattern = #"<style[^>]*>([\s\S]*?)</style>"#
        if let styleRegex = try? NSRegularExpression(pattern: stylePattern, options: [.caseInsensitive]) {
            // Find styles in <head> section
            let headPattern = #"<head[^>]*>([\s\S]*?)</head>"#
            if let headRegex = try? NSRegularExpression(pattern: headPattern, options: [.caseInsensitive]) {
                let nsHtml = html as NSString
                let headMatches = headRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
                for headMatch in headMatches {
                    let headContent = nsHtml.substring(with: headMatch.range)
                    let nsHead = headContent as NSString
                    let styleMatches = styleRegex.matches(in: headContent, range: NSRange(location: 0, length: nsHead.length))
                    for sm in styleMatches {
                        styles += nsHead.substring(with: sm.range) + "\n"
                    }
                }
            }
        }

        // Also include the combined CSS
        if !combinedCSS.isEmpty {
            styles += "<style>\n\(combinedCSS)\n</style>\n"
        }

        // Extract <body> content
        let bodyPattern = #"<body[^>]*>([\s\S]*)</body>"#
        if let bodyRegex = try? NSRegularExpression(pattern: bodyPattern, options: [.caseInsensitive]) {
            let nsBody = body as NSString
            let matches = bodyRegex.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
            if let match = matches.first, match.numberOfRanges >= 2 {
                body = nsBody.substring(with: match.range(at: 1))
            }
        }

        return styles + body
    }
}
