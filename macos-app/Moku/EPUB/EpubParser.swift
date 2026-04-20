import Foundation
import ZIPFoundation

enum EpubParserError: LocalizedError {
    case invalidArchive
    case containerNotFound
    case opfPathNotFound
    case opfNotFound
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchive: "The file is not a valid EPUB archive."
        case .containerNotFound: "META-INF/container.xml not found."
        case .opfPathNotFound: "Could not locate OPF path in container.xml."
        case .opfNotFound: "OPF file not found in archive."
        case .parseError(let msg): "EPUB parse error: \(msg)"
        }
    }
}

enum EpubParser {

    // MARK: - Public

    static func parse(data: Data) throws -> EpubDocument {
        guard let archive = Archive(data: data, accessMode: .read) else {
            throw EpubParserError.invalidArchive
        }

        let opfPath = try findOpfPath(archive: archive)
        let opfDirectory = (opfPath as NSString).deletingLastPathComponent
        let opfData = try extractEntry(archive: archive, path: opfPath)

        let opfDoc = try XMLDocument(data: opfData, options: [.nodePreserveAll])

        let manifest = parseManifest(opfDoc: opfDoc)
        let manifestById = Dictionary(manifest.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        let spine = parseSpine(opfDoc: opfDoc, manifestById: manifestById)
        let metadata = parseMetadata(opfDoc: opfDoc, manifestById: manifestById)
        let toc = parseToc(
            archive: archive,
            manifest: manifest,
            opfDirectory: opfDirectory,
            opfDoc: opfDoc
        )
        let resources = loadResources(archive: archive)

        return EpubDocument(
            metadata: metadata,
            manifest: manifest,
            spine: spine,
            toc: toc,
            resources: resources,
            opfDirectory: opfDirectory
        )
    }

    // MARK: - OPF Location

    static func findOpfPath(archive: Archive) throws -> String {
        let containerData = try extractEntry(archive: archive, path: "META-INF/container.xml")
        let containerDoc = try XMLDocument(data: containerData, options: [.nodePreserveAll])

        // Try with namespace first, then without
        let xpaths = [
            "//container:rootfile/@full-path",
            "//rootfile/@full-path",
        ]
        let namespaces = ["container": "urn:oasis:names:tc:opendocument:xmlns:container"]

        for xpath in xpaths {
            if let nodes = try? containerDoc.nodes(forXPath: xpath) {
                for node in nodes {
                    if let path = node.stringValue, !path.isEmpty {
                        return path
                    }
                }
            }
            // Try with explicit namespace mapping
            if xpath.contains("container:") {
                let nsXpath = xpath
                if let root = containerDoc.rootElement() {
                    for (prefix, uri) in namespaces {
                        root.addNamespace(XMLNode.namespace(withName: prefix, stringValue: uri) as! XMLNode)
                    }
                }
                if let nodes = try? containerDoc.nodes(forXPath: nsXpath) {
                    for node in nodes {
                        if let path = node.stringValue, !path.isEmpty {
                            return path
                        }
                    }
                }
            }
        }

        // Fallback: scan for .opf files in archive
        for entry in archive {
            if entry.path.hasSuffix(".opf") {
                return entry.path
            }
        }

        throw EpubParserError.opfPathNotFound
    }

    // MARK: - Metadata

    static func parseMetadata(opfDoc: XMLDocument, manifestById: [String: ManifestItem]) -> EpubMetadata {
        let root = opfDoc.rootElement()

        // Helper to find text in common metadata XPaths
        func metaText(_ localName: String) -> String? {
            let xpaths = [
                "//dc:\(localName)",
                "//opf:metadata/dc:\(localName)",
                "//*[local-name()='\(localName)']",
            ]
            for xpath in xpaths {
                if let nodes = try? opfDoc.nodes(forXPath: xpath) {
                    for node in nodes {
                        if let text = node.stringValue, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return text.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
            }
            return nil
        }

        func allMetaText(_ localName: String) -> [String] {
            let xpath = "//*[local-name()='\(localName)']"
            guard let nodes = try? opfDoc.nodes(forXPath: xpath) else { return [] }
            return nodes.compactMap { node in
                guard let text = node.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { return nil }
                return text
            }
        }

        let title = metaText("title") ?? "Untitled"
        var authors = allMetaText("creator")
        if authors.isEmpty, let single = metaText("creator") {
            authors = [single]
        }

        let description = metaText("description")
        let publisher = metaText("publisher")
        let language = metaText("language")

        // ISBN from dc:identifier
        var isbn: String?
        let identifiers = allMetaText("identifier")
        for id in identifiers {
            let cleaned = id.replacingOccurrences(of: "-", with: "")
            if cleaned.range(of: #"^\d{10}(\d{3})?$"#, options: .regularExpression) != nil {
                isbn = id
                break
            }
        }

        // Cover manifest ID from <meta name="cover" content="...">
        var coverManifestId: String?
        if let metaNodes = try? opfDoc.nodes(forXPath: "//*[local-name()='meta']") {
            for node in metaNodes {
                if let element = node as? XMLElement,
                   element.attribute(forName: "name")?.stringValue == "cover",
                   let content = element.attribute(forName: "content")?.stringValue
                {
                    coverManifestId = content
                    break
                }
            }
        }

        // Also check for cover-image property in manifest
        if coverManifestId == nil {
            for (id, item) in manifestById where item.isCoverImage {
                coverManifestId = id
                break
            }
        }

        return EpubMetadata(
            title: title,
            authors: authors,
            description: description,
            publisher: publisher,
            language: language,
            isbn: isbn,
            coverManifestId: coverManifestId
        )
    }

    // MARK: - Manifest

    static func parseManifest(opfDoc: XMLDocument) -> [ManifestItem] {
        var items: [ManifestItem] = []
        let xpaths = [
            "//*[local-name()='manifest']/*[local-name()='item']",
            "//manifest/item",
        ]

        for xpath in xpaths {
            guard let nodes = try? opfDoc.nodes(forXPath: xpath) else { continue }
            for node in nodes {
                guard let element = node as? XMLElement,
                      let id = element.attribute(forName: "id")?.stringValue,
                      let href = element.attribute(forName: "href")?.stringValue,
                      let mediaType = element.attribute(forName: "media-type")?.stringValue
                else { continue }

                let properties = element.attribute(forName: "properties")?.stringValue
                items.append(ManifestItem(id: id, href: href, mediaType: mediaType, properties: properties))
            }
            if !items.isEmpty { break }
        }

        return items
    }

    // MARK: - Spine

    static func parseSpine(opfDoc: XMLDocument, manifestById: [String: ManifestItem]) -> [SpineEntry] {
        var entries: [SpineEntry] = []
        let xpaths = [
            "//*[local-name()='spine']/*[local-name()='itemref']",
            "//spine/itemref",
        ]

        for xpath in xpaths {
            guard let nodes = try? opfDoc.nodes(forXPath: xpath) else { continue }
            for node in nodes {
                guard let element = node as? XMLElement,
                      let idRef = element.attribute(forName: "idref")?.stringValue
                else { continue }

                let linear = element.attribute(forName: "linear")?.stringValue != "no"
                let item = manifestById[idRef]

                entries.append(SpineEntry(
                    idRef: idRef,
                    isLinear: linear,
                    href: item?.href ?? "",
                    mediaType: item?.mediaType ?? "application/xhtml+xml"
                ))
            }
            if !entries.isEmpty { break }
        }

        return entries
    }

    // MARK: - TOC

    static func parseToc(
        archive: Archive,
        manifest: [ManifestItem],
        opfDirectory: String,
        opfDoc: XMLDocument
    ) -> [TocEntry] {
        // EPUB 3: try nav document first
        if let navItem = manifest.first(where: { $0.isNav }) {
            let navPath = opfDirectory.isEmpty ? navItem.href : opfDirectory + "/" + navItem.href
            if let navData = try? extractEntry(archive: archive, path: navPath),
               let navString = String(data: navData, encoding: .utf8)
            {
                let entries = parseNavXhtml(xhtml: navString, basePath: (navPath as NSString).deletingLastPathComponent)
                if !entries.isEmpty { return entries }
            }
        }

        // EPUB 2 fallback: NCX
        // Find NCX from spine toc attribute or manifest
        var ncxItem: ManifestItem?

        // Check spine element for toc attribute
        if let spineNodes = try? opfDoc.nodes(forXPath: "//*[local-name()='spine']"),
           let spineElement = spineNodes.first as? XMLElement,
           let tocId = spineElement.attribute(forName: "toc")?.stringValue
        {
            ncxItem = manifest.first { $0.id == tocId }
        }

        // Fallback: look for NCX media type
        if ncxItem == nil {
            ncxItem = manifest.first { $0.mediaType == "application/x-dtbncx+xml" }
        }

        if let ncxItem = ncxItem {
            let ncxPath = opfDirectory.isEmpty ? ncxItem.href : opfDirectory + "/" + ncxItem.href
            if let ncxData = try? extractEntry(archive: archive, path: ncxPath),
               let ncxString = String(data: ncxData, encoding: .utf8)
            {
                return parseNcx(ncxXml: ncxString, basePath: (ncxPath as NSString).deletingLastPathComponent)
            }
        }

        return []
    }

    /// Parse EPUB 3 nav XHTML into TocEntry tree.
    static func parseNavXhtml(xhtml: String, basePath: String = "") -> [TocEntry] {
        guard let data = xhtml.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: [.nodePreserveAll, .documentTidyHTML])
        else { return [] }

        // Find the <nav epub:type="toc"> or first <nav>
        let navXpaths = [
            "//*[local-name()='nav'][@*[local-name()='type']='toc']",
            "//*[local-name()='nav']",
        ]

        var navElement: XMLElement?
        for xpath in navXpaths {
            if let nodes = try? doc.nodes(forXPath: xpath), let el = nodes.first as? XMLElement {
                navElement = el
                break
            }
        }

        guard let nav = navElement else { return [] }

        // Find the top-level <ol> inside nav
        guard let olNodes = try? nav.nodes(forXPath: "*[local-name()='ol']"),
              let ol = olNodes.first as? XMLElement
        else { return [] }

        return parseNavOl(ol: ol, basePath: basePath)
    }

    private static func parseNavOl(ol: XMLElement, basePath: String) -> [TocEntry] {
        var entries: [TocEntry] = []

        guard let liNodes = try? ol.nodes(forXPath: "*[local-name()='li']") else {
            return entries
        }

        for liNode in liNodes {
            guard let li = liNode as? XMLElement else { continue }

            // Get <a> element
            guard let aNodes = try? li.nodes(forXPath: "*[local-name()='a']"),
                  let a = aNodes.first as? XMLElement,
                  let rawHref = a.attribute(forName: "href")?.stringValue
            else { continue }

            let title = a.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { continue }

            let fullHref = resolveHref(rawHref, basePath: basePath)
            let (path, fragment) = splitFragment(fullHref)

            // Recurse into nested <ol>
            var children: [TocEntry] = []
            if let subOlNodes = try? li.nodes(forXPath: "*[local-name()='ol']"),
               let subOl = subOlNodes.first as? XMLElement
            {
                children = parseNavOl(ol: subOl, basePath: basePath)
            }

            entries.append(TocEntry(
                title: title,
                href: path,
                fragment: fragment,
                fullHref: fullHref,
                children: children
            ))
        }

        return entries
    }

    /// Parse EPUB 2 NCX into TocEntry tree.
    static func parseNcx(ncxXml: String, basePath: String = "") -> [TocEntry] {
        guard let data = ncxXml.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: [.nodePreserveAll])
        else { return [] }

        // Find <navMap>
        guard let navMapNodes = try? doc.nodes(forXPath: "//*[local-name()='navMap']"),
              let navMap = navMapNodes.first as? XMLElement
        else { return [] }

        return parseNcxNavPoints(parent: navMap, basePath: basePath)
    }

    private static func parseNcxNavPoints(parent: XMLElement, basePath: String) -> [TocEntry] {
        var entries: [TocEntry] = []

        guard let navPoints = try? parent.nodes(forXPath: "*[local-name()='navPoint']") else {
            return entries
        }

        for npNode in navPoints {
            guard let np = npNode as? XMLElement else { continue }

            // Get title from <navLabel><text>
            let title: String
            if let textNodes = try? np.nodes(forXPath: "*[local-name()='navLabel']/*[local-name()='text']"),
               let text = textNodes.first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty
            {
                title = text
            } else {
                continue
            }

            // Get href from <content src="...">
            guard let contentNodes = try? np.nodes(forXPath: "*[local-name()='content']"),
                  let contentEl = contentNodes.first as? XMLElement,
                  let rawSrc = contentEl.attribute(forName: "src")?.stringValue
            else { continue }

            let fullHref = resolveHref(rawSrc, basePath: basePath)
            let (path, fragment) = splitFragment(fullHref)

            let children = parseNcxNavPoints(parent: np, basePath: basePath)

            entries.append(TocEntry(
                title: title,
                href: path,
                fragment: fragment,
                fullHref: fullHref,
                children: children
            ))
        }

        return entries
    }

    // MARK: - Resources

    static func loadResources(archive: Archive) -> [String: EpubResource] {
        var resources: [String: EpubResource] = [:]

        for entry in archive where entry.type == .file {
            let path = entry.path
            guard !path.hasPrefix("META-INF/"), path != "mimetype" else { continue }

            var entryData = Data()
            do {
                _ = try archive.extract(entry) { chunk in entryData.append(chunk) }
            } catch {
                continue
            }

            let mediaType = guessMediaType(path: path)
            resources[path] = EpubResource(href: path, mediaType: mediaType, data: entryData)
        }

        return resources
    }

    // MARK: - Helpers

    static func guessMediaType(path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "xhtml", "xht": return "application/xhtml+xml"
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "xml": return "application/xml"
        case "ncx": return "application/x-dtbncx+xml"
        case "opf": return "application/oebps-package+xml"
        case "mp3": return "audio/mpeg"
        case "mp4": return "video/mp4"
        case "smil": return "application/smil+xml"
        default: return "application/octet-stream"
        }
    }

    private static func extractEntry(archive: Archive, path: String) throws -> Data {
        // Try exact path first
        if let entry = archive[path] {
            var data = Data()
            _ = try archive.extract(entry) { chunk in data.append(chunk) }
            return data
        }

        // Case-insensitive fallback
        let lowered = path.lowercased()
        for entry in archive where entry.path.lowercased() == lowered {
            var data = Data()
            _ = try archive.extract(entry) { chunk in data.append(chunk) }
            return data
        }

        throw EpubParserError.containerNotFound
    }

    private static func resolveHref(_ href: String, basePath: String) -> String {
        let decoded = href.removingPercentEncoding ?? href
        if decoded.hasPrefix("/") || decoded.contains("://") {
            return decoded
        }
        if basePath.isEmpty {
            return decoded
        }
        // Resolve relative path
        let base = URL(fileURLWithPath: "/" + basePath, isDirectory: true)
        let resolved = URL(fileURLWithPath: decoded, relativeTo: base)
        var path = resolved.standardized.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        return path
    }

    private static func splitFragment(_ href: String) -> (path: String, fragment: String?) {
        guard let hashIndex = href.firstIndex(of: "#") else {
            return (href, nil)
        }
        let path = String(href[href.startIndex..<hashIndex])
        let fragment = String(href[href.index(after: hashIndex)...])
        return (path, fragment.isEmpty ? nil : fragment)
    }
}
