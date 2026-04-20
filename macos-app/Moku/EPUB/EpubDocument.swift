import Foundation

// MARK: - EpubDocument

struct EpubDocument: Sendable {
    let metadata: EpubMetadata
    let manifest: [ManifestItem]
    let spine: [SpineEntry]
    let toc: [TocEntry]
    let resources: [String: EpubResource]
    let opfDirectory: String

    /// Flexibly locate a resource by href.
    /// Tries: exact match, OPF-dir prefixed, basename match, URL-decoded variants.
    func findResource(href: String) -> EpubResource? {
        let cleaned = href.removingPercentEncoding ?? href

        // Exact match
        if let r = resources[cleaned] { return r }
        if let r = resources[href] { return r }

        // Prefixed with OPF directory
        if !opfDirectory.isEmpty {
            let prefixed = opfDirectory + "/" + cleaned
            if let r = resources[prefixed] { return r }
        }

        // Strip OPF directory prefix
        if !opfDirectory.isEmpty, cleaned.hasPrefix(opfDirectory + "/") {
            let stripped = String(cleaned.dropFirst(opfDirectory.count + 1))
            if let r = resources[stripped] { return r }
        }

        // Basename match
        let targetBase = (cleaned as NSString).lastPathComponent
        for (key, resource) in resources {
            if (key as NSString).lastPathComponent == targetBase {
                return resource
            }
        }

        return nil
    }
}

// MARK: - EpubMetadata

struct EpubMetadata: Sendable {
    let title: String
    let authors: [String]
    let description: String?
    let publisher: String?
    let language: String?
    let isbn: String?
    let coverManifestId: String?
}

// MARK: - ManifestItem

struct ManifestItem: Sendable {
    let id: String
    let href: String
    let mediaType: String
    let properties: String?

    var isHtml: Bool {
        mediaType == "application/xhtml+xml" || mediaType == "text/html"
    }

    var isCss: Bool {
        mediaType == "text/css"
    }

    var isImage: Bool {
        mediaType.hasPrefix("image/")
    }

    var isNav: Bool {
        properties?.contains("nav") == true
    }

    var isCoverImage: Bool {
        properties?.contains("cover-image") == true
    }
}

// MARK: - SpineEntry

struct SpineEntry: Sendable {
    let idRef: String
    let isLinear: Bool
    let href: String
    let mediaType: String
}

// MARK: - TocEntry

struct TocEntry: Sendable {
    let title: String
    let href: String      // path without fragment
    let fragment: String?
    let fullHref: String   // original href including fragment
    let children: [TocEntry]

    /// Depth-first flattening of this entry and all descendants.
    func flatten() -> [TocEntry] {
        var result = [self]
        for child in children {
            result.append(contentsOf: child.flatten())
        }
        return result
    }
}

// MARK: - EpubResource

struct EpubResource: Sendable {
    let href: String
    let mediaType: String
    let data: Data

    /// UTF-8 text content with lossy fallback.
    var textContent: String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .ascii)
            ?? ""
    }
}

// MARK: - ReadingChapter

struct ReadingChapter: Sendable {
    let index: Int
    let title: String
    let contentHref: String
    let fragment: String?
}
