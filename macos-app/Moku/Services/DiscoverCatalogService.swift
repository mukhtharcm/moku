import Foundation

enum DiscoverCatalogKind: String, Codable {
    case openLibrary
    case gutenberg
    case custom
}

enum DiscoverCatalogProtocol: String, Codable {
    case opds1
    case opds2
}

struct DiscoverCatalogSource: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let url: String
    let kind: DiscoverCatalogKind
    let protocolType: DiscoverCatalogProtocol
    let searchTemplate: String?

    var isCustom: Bool { kind == .custom }
    var resolvedURL: URL? { URL(string: url) }
}

struct DiscoverCatalogAcquisition: Identifiable, Hashable {
    let url: URL
    let mediaType: String
    let format: BookFormat
    let title: String?

    var id: String { "\(url.absoluteString)|\(mediaType)" }
}

struct DiscoverCatalogBook: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let description: String?
    let coverURL: URL?
    let yearLabel: String?
    let subjects: [String]
    let externalURL: URL?
    let catalogID: String
    let catalogTitle: String
    let acquisitions: [DiscoverCatalogAcquisition]

    var preferredAcquisition: DiscoverCatalogAcquisition? {
        acquisitions.first
    }

    var formatSummary: String {
        Array(Set(acquisitions.map(\.format.displayName))).sorted().joined(separator: " · ")
    }
}

enum DiscoverCatalogError: LocalizedError {
    case invalidURL
    case requestFailed(Int)
    case invalidResponse
    case unsupportedCatalog
    case searchUnavailable
    case downloadFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter a valid catalog URL."
        case .requestFailed(let status):
            "The catalog request failed (\(status))."
        case .invalidResponse:
            "The catalog returned an invalid response."
        case .unsupportedCatalog:
            "This catalog doesn't expose a compatible OPDS search feed."
        case .searchUnavailable:
            "This catalog doesn't expose a search template."
        case .downloadFailed(let status):
            "The book download failed (\(status))."
        }
    }
}

@MainActor
final class DiscoverCatalogService {
    private let session: URLSession
    private let defaults: UserDefaults

    private let customCatalogsKey = "discover.customCatalogs"

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.defaults = defaults
    }

    private static let builtInCatalogs: [DiscoverCatalogSource] = [
        DiscoverCatalogSource(
            id: "open-library",
            title: "Open Library",
            url: "https://openlibrary.org/opds/",
            kind: .openLibrary,
            protocolType: .opds2,
            searchTemplate: nil
        ),
        DiscoverCatalogSource(
            id: "project-gutenberg",
            title: "Project Gutenberg",
            url: "https://www.gutenberg.org/ebooks/search.opds/",
            kind: .gutenberg,
            protocolType: .opds1,
            searchTemplate: "https://www.gutenberg.org/ebooks/search.opds/?query={searchTerms}"
        ),
    ]

    func loadCatalogs() -> [DiscoverCatalogSource] {
        Self.builtInCatalogs + loadCustomCatalogs()
    }

    func addCustomCatalog(title: String, urlString: String) async throws -> DiscoverCatalogSource {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw DiscoverCatalogError.invalidURL
        }
        guard let normalized = normalizeURL(urlString) else {
            throw DiscoverCatalogError.invalidURL
        }

        let prepared = try await prepareCustomCatalog(title: trimmedTitle, rootURL: normalized)
        var existing = loadCustomCatalogs()
        guard !existing.contains(where: { $0.url == prepared.url }) else {
            throw NSError(
                domain: "MokuDiscover",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "That catalog is already added."]
            )
        }
        existing.append(prepared)
        saveCustomCatalogs(existing)
        return prepared
    }

    func removeCustomCatalog(id: String) {
        let filtered = loadCustomCatalogs().filter { $0.id != id }
        saveCustomCatalogs(filtered)
    }

    func searchBooks(in catalog: DiscoverCatalogSource, query: String) async throws -> [DiscoverCatalogBook] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        switch catalog.kind {
        case .openLibrary:
            return try await searchOpenLibrary(catalog: catalog, query: trimmed)
        case .gutenberg, .custom:
            switch catalog.protocolType {
            case .opds1:
                return try await searchOPDS1(catalog: catalog, query: trimmed)
            case .opds2:
                return try await searchOPDS2(catalog: catalog, query: trimmed)
            }
        }
    }

    func downloadAcquisition(
        _ acquisition: DiscoverCatalogAcquisition,
        suggestedName: String
    ) async throws -> URL {
        let resolved = try await downloadResolvedAcquisition(
            from: acquisition.url,
            expectedFormat: acquisition.format
        )

        let extensionName = fileExtension(
            for: acquisition,
            preferredName: resolved.finalURL.lastPathComponent.isEmpty
                ? suggestedName
                : resolved.finalURL.lastPathComponent
        )
        let slug = slugify(suggestedName)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(slug)-\(UUID().uuidString)")
            .appendingPathExtension(extensionName)
        try resolved.data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func downloadResolvedAcquisition(
        from url: URL,
        expectedFormat: BookFormat,
        depth: Int = 0
    ) async throws -> ResolvedDownload {
        if depth > 3 {
            throw NSError(
                domain: "MokuDiscover",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Download redirected too many times."]
            )
        }

        var request = URLRequest(url: url)
        request.setValue(
            "application/epub+zip,application/pdf,text/plain,text/html,*/*",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("Moku/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscoverCatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DiscoverCatalogError.downloadFailed(httpResponse.statusCode)
        }

        let responseURL = httpResponse.url ?? url
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""

        if expectedFormat != .html,
           looksLikeHTMLResponse(contentType: contentType, data: data),
           let html = String(data: data, encoding: .utf8),
           let followUpURL = extractFollowUpDownloadURL(from: html, baseURL: responseURL),
           followUpURL != responseURL {
            return try await downloadResolvedAcquisition(
                from: followUpURL,
                expectedFormat: expectedFormat,
                depth: depth + 1
            )
        }

        return ResolvedDownload(data: data, finalURL: responseURL)
    }

    private func loadCustomCatalogs() -> [DiscoverCatalogSource] {
        guard let data = defaults.data(forKey: customCatalogsKey) else { return [] }
        return (try? JSONDecoder().decode([DiscoverCatalogSource].self, from: data)) ?? []
    }

    private func saveCustomCatalogs(_ catalogs: [DiscoverCatalogSource]) {
        let data = try? JSONEncoder().encode(catalogs)
        defaults.set(data, forKey: customCatalogsKey)
    }

    private func searchOpenLibrary(
        catalog: DiscoverCatalogSource,
        query: String
    ) async throws -> [DiscoverCatalogBook] {
        var components = URLComponents(string: "https://openlibrary.org/opds/search")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "mode", value: "open_access"),
            URLQueryItem(name: "limit", value: "20"),
        ]
        guard let url = components?.url else {
            throw DiscoverCatalogError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscoverCatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DiscoverCatalogError.requestFailed(httpResponse.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DiscoverCatalogError.invalidResponse
        }
        return parseOPDS2Feed(catalog: catalog, baseURL: url, json: json)
    }

    private func searchOPDS2(
        catalog: DiscoverCatalogSource,
        query: String
    ) async throws -> [DiscoverCatalogBook] {
        guard let template = catalog.searchTemplate else {
            throw DiscoverCatalogError.searchUnavailable
        }
        let url = expandSearchTemplate(template, query: query)
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscoverCatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DiscoverCatalogError.requestFailed(httpResponse.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DiscoverCatalogError.invalidResponse
        }
        return parseOPDS2Feed(catalog: catalog, baseURL: url, json: json)
    }

    private func searchOPDS1(
        catalog: DiscoverCatalogSource,
        query: String
    ) async throws -> [DiscoverCatalogBook] {
        guard let template = catalog.searchTemplate else {
            throw DiscoverCatalogError.searchUnavailable
        }
        let url = expandSearchTemplate(template, query: query)
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscoverCatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DiscoverCatalogError.requestFailed(httpResponse.statusCode)
        }
        let document = try XMLDocument(data: data)
        return try parseOPDS1Feed(catalog: catalog, baseURL: url, document: document)
    }

    private func prepareCustomCatalog(
        title: String,
        rootURL: URL
    ) async throws -> DiscoverCatalogSource {
        let (data, response) = try await session.data(from: rootURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscoverCatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DiscoverCatalogError.requestFailed(httpResponse.statusCode)
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let body = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        if contentType.contains("application/opds+json") || body.first == "{" {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let template = extractOPDS2SearchTemplate(json: json, baseURL: rootURL) else {
                throw DiscoverCatalogError.unsupportedCatalog
            }
            return DiscoverCatalogSource(
                id: "custom-\(UUID().uuidString)",
                title: title,
                url: rootURL.absoluteString,
                kind: .custom,
                protocolType: .opds2,
                searchTemplate: template
            )
        }

        let document = try XMLDocument(data: data)
        guard let openSearchURL = try extractOPDS1SearchDescriptionURL(document: document, baseURL: rootURL) else {
            throw DiscoverCatalogError.unsupportedCatalog
        }

        let (openSearchData, openSearchResponse) = try await session.data(from: openSearchURL)
        guard let openSearchHTTP = openSearchResponse as? HTTPURLResponse else {
            throw DiscoverCatalogError.invalidResponse
        }
        guard (200..<300).contains(openSearchHTTP.statusCode) else {
            throw DiscoverCatalogError.requestFailed(openSearchHTTP.statusCode)
        }
        let openSearchDocument = try XMLDocument(data: openSearchData)
        guard let template = try extractOpenSearchTemplate(document: openSearchDocument) else {
            throw DiscoverCatalogError.unsupportedCatalog
        }

        let resolvedTemplate = absoluteURLString(template, relativeTo: openSearchURL)
        return DiscoverCatalogSource(
            id: "custom-\(UUID().uuidString)",
            title: title,
            url: rootURL.absoluteString,
            kind: .custom,
            protocolType: .opds1,
            searchTemplate: resolvedTemplate
        )
    }

    private func parseOPDS2Feed(
        catalog: DiscoverCatalogSource,
        baseURL: URL,
        json: [String: Any]
    ) -> [DiscoverCatalogBook] {
        let publications = readPublications(from: json["publications"]) + readGroupedPublications(from: json["groups"])

        return publications.compactMap { publication in
            let metadata = publication["metadata"] as? [String: Any] ?? [:]
            let links = publication["links"] as? [[String: Any]] ?? []
            let acquisitions = parseOPDS2Acquisitions(links: links, baseURL: baseURL)
            guard !acquisitions.isEmpty else { return nil }

            let title = (metadata["title"] as? String)?.trimmedNonEmpty
            guard let title else { return nil }

            return DiscoverCatalogBook(
                id: (publication["id"] as? String) ??
                    (metadata["identifier"] as? String) ??
                    acquisitions[0].url.absoluteString,
                title: title,
                author: extractAuthor(from: metadata["author"]).trimmedNonEmpty ?? "Unknown Author",
                description: extractDescription(from: metadata["description"]),
                coverURL: extractOPDS2Cover(images: publication["images"], links: links, baseURL: baseURL),
                yearLabel: extractYear(from: metadata),
                subjects: extractSubjects(from: metadata["subject"]),
                externalURL: extractAlternateURL(from: links, baseURL: baseURL),
                catalogID: catalog.id,
                catalogTitle: catalog.title,
                acquisitions: acquisitions
            )
        }
    }

    private func parseOPDS1Feed(
        catalog: DiscoverCatalogSource,
        baseURL: URL,
        document: XMLDocument
    ) throws -> [DiscoverCatalogBook] {
        let entries = try document.nodes(forXPath: "//*[local-name()='entry']")
        return entries.compactMap { node in
            guard let entry = node as? XMLElement else { return nil }
            let acquisitions = parseOPDS1Acquisitions(entry: entry, baseURL: baseURL)
            guard !acquisitions.isEmpty else { return nil }
            guard let title = firstString(in: entry, xpath: "./*[local-name()='title'][1]") else {
                return nil
            }

            let author = firstString(
                in: entry,
                xpath: "./*[local-name()='author'][1]/*[local-name()='name'][1]"
            ) ?? "Unknown Author"

            return DiscoverCatalogBook(
                id: firstString(in: entry, xpath: "./*[local-name()='id'][1]") ?? acquisitions[0].url.absoluteString,
                title: title,
                author: author,
                description: firstString(in: entry, xpath: "./*[local-name()='content'][1]"),
                coverURL: extractOPDS1Cover(entry: entry, baseURL: baseURL),
                yearLabel: firstString(in: entry, xpath: "./*[local-name()='published'][1]")?.prefix(4).description,
                subjects: [],
                externalURL: extractOPDS1AlternateURL(entry: entry, baseURL: baseURL),
                catalogID: catalog.id,
                catalogTitle: catalog.title,
                acquisitions: acquisitions
            )
        }
    }

    private func parseOPDS2Acquisitions(
        links: [[String: Any]],
        baseURL: URL
    ) -> [DiscoverCatalogAcquisition] {
        let acquisitions = links.compactMap { link -> DiscoverCatalogAcquisition? in
            let relValues = relList(from: link["rel"])
            guard relValues.contains(where: isAcquisitionRelation(_:)) else { return nil }
            guard let href = link["href"] as? String,
                  let mediaType = (link["type"] as? String)?.trimmedNonEmpty,
                  let format = formatFromMediaType(mediaType) else {
                return nil
            }
            return DiscoverCatalogAcquisition(
                url: absoluteURL(href, relativeTo: baseURL),
                mediaType: mediaType,
                format: format,
                title: link["title"] as? String
            )
        }
        return acquisitions.sorted(by: acquisitionComparator)
    }

    private func parseOPDS1Acquisitions(
        entry: XMLElement,
        baseURL: URL
    ) -> [DiscoverCatalogAcquisition] {
        let links = (try? entry.nodes(forXPath: "./*[local-name()='link']")) ?? []
        let acquisitions = links.compactMap { node -> DiscoverCatalogAcquisition? in
            guard let link = node as? XMLElement else { return nil }
            let rel = link.attribute(forName: "rel")?.stringValue ?? ""
            guard isAcquisitionRelation(rel) else { return nil }
            guard let href = link.attribute(forName: "href")?.stringValue,
                  let mediaType = link.attribute(forName: "type")?.stringValue,
                  let format = formatFromMediaType(mediaType) else {
                return nil
            }

            return DiscoverCatalogAcquisition(
                url: absoluteURL(href, relativeTo: baseURL),
                mediaType: mediaType,
                format: format,
                title: link.attribute(forName: "title")?.stringValue
            )
        }
        return acquisitions.sorted(by: acquisitionComparator)
    }

    private func extractOPDS2SearchTemplate(
        json: [String: Any],
        baseURL: URL
    ) -> String? {
        let links = json["links"] as? [[String: Any]] ?? []
        for link in links {
            let rels = relList(from: link["rel"])
            guard rels.contains("search"),
                  let href = link["href"] as? String else {
                continue
            }
            return absoluteURLString(href, relativeTo: baseURL)
        }
        return nil
    }

    private func extractOPDS1SearchDescriptionURL(
        document: XMLDocument,
        baseURL: URL
    ) throws -> URL? {
        let links = try document.nodes(forXPath: "//*[local-name()='link']")
        for node in links {
            guard let link = node as? XMLElement else { continue }
            let rel = link.attribute(forName: "rel")?.stringValue
            let type = link.attribute(forName: "type")?.stringValue ?? ""
            let href = link.attribute(forName: "href")?.stringValue
            if rel == "search",
               type.contains("application/opensearchdescription+xml"),
               let href, !href.isEmpty {
                return absoluteURL(href, relativeTo: baseURL)
            }
        }
        return nil
    }

    private func extractOpenSearchTemplate(document: XMLDocument) throws -> String? {
        let nodes = try document.nodes(forXPath: "//*[local-name()='Url']")
        for node in nodes {
            guard let element = node as? XMLElement else { continue }
            let type = element.attribute(forName: "type")?.stringValue ?? ""
            if (type.contains("opds-catalog") || type.contains("atom+xml")),
               let template = element.attribute(forName: "template")?.stringValue?.trimmedNonEmpty {
                return template
            }
        }
        return nodes
            .compactMap { ($0 as? XMLElement)?.attribute(forName: "template")?.stringValue?.trimmedNonEmpty }
            .first
    }

    private func expandSearchTemplate(_ template: String, query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        var result = template
        result = result.replacingOccurrences(of: "{searchTerms}", with: encoded)
        result = result.replacingOccurrences(of: "{query}", with: encoded)

        if let match = result.range(of: #"\{\?([^}]+)\}"#, options: .regularExpression) {
            let inner = String(result[match]).dropFirst(2).dropLast()
            let params = inner.split(separator: ",").map { String($0) }
            var items: [URLQueryItem] = []
            for param in params {
                switch param {
                case "query", "q":
                    items.append(URLQueryItem(name: param, value: query))
                case "searchTerms":
                    items.append(URLQueryItem(name: "query", value: query))
                default:
                    break
                }
            }
            let replacement = items.isEmpty ? "" : "?\(items.compactMap { $0.name + "=" + (($0.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)) ?? "") }.joined(separator: "&"))"
            result.replaceSubrange(match, with: replacement)
        }

        if let match = result.range(of: #"\{\&([^}]+)\}"#, options: .regularExpression) {
            let inner = String(result[match]).dropFirst(2).dropLast()
            let params = inner.split(separator: ",").map { String($0) }
            var items: [String] = []
            for param in params {
                switch param {
                case "query", "q":
                    items.append("\(param)=\(encoded)")
                case "searchTerms":
                    items.append("query=\(encoded)")
                default:
                    break
                }
            }
            let separator = result.contains("?") ? "&" : "?"
            result.replaceSubrange(match, with: items.isEmpty ? "" : separator + items.joined(separator: "&"))
        }

        result = result.replacingOccurrences(of: #"\{[^}]+\}"#, with: "", options: .regularExpression)
        return URL(string: result) ?? URL(string: template)!
    }

    private func normalizeURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
        guard let url = URL(string: withScheme), url.host?.isEmpty == false else { return nil }
        return url
    }

    private func readPublications(from raw: Any?) -> [[String: Any]] {
        (raw as? [[String: Any]]) ?? []
    }

    private func readGroupedPublications(from raw: Any?) -> [[String: Any]] {
        guard let groups = raw as? [[String: Any]] else { return [] }
        return groups.flatMap { readPublications(from: $0["publications"]) }
    }

    private func relList(from raw: Any?) -> [String] {
        if let string = raw as? String { return [string] }
        if let array = raw as? [String] { return array }
        return []
    }

    private func isAcquisitionRelation(_ rel: String) -> Bool {
        rel.hasPrefix("http://opds-spec.org/acquisition")
    }

    private func formatFromMediaType(_ mediaType: String) -> BookFormat? {
        let normalized = mediaType
            .split(separator: ";")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? mediaType.lowercased()

        return switch normalized {
        case "application/epub+zip":
            .epub
        case "application/pdf":
            .pdf
        case "text/plain":
            .txt
        case "text/html", "application/xhtml+xml":
            .html
        default:
            nil
        }
    }

    private func acquisitionComparator(
        _ lhs: DiscoverCatalogAcquisition,
        _ rhs: DiscoverCatalogAcquisition
    ) -> Bool {
        priority(for: lhs.format) < priority(for: rhs.format)
    }

    private func priority(for format: BookFormat) -> Int {
        switch format {
        case .epub: 0
        case .pdf: 1
        case .html: 2
        case .txt: 3
        case .cbz: 4
        }
    }

    private func extractAuthor(from raw: Any?) -> String {
        if let string = raw as? String { return string }
        if let object = raw as? [String: Any] { return (object["name"] as? String) ?? "" }
        if let array = raw as? [Any] {
            return array.compactMap { item in
                if let string = item as? String { return string }
                if let object = item as? [String: Any] { return object["name"] as? String }
                return nil
            }.joined(separator: ", ")
        }
        return ""
    }

    private func extractDescription(from raw: Any?) -> String? {
        if let string = raw as? String {
            return string.trimmedNonEmpty
        }
        if let object = raw as? [String: Any] {
            for key in ["value", "text", "html"] {
                if let value = object[key] as? String, let trimmed = value.trimmedNonEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private func extractYear(from metadata: [String: Any]) -> String? {
        for key in ["published", "modified", "issued"] {
            if let value = metadata[key] as? String, value.count >= 4 {
                return String(value.prefix(4))
            }
        }
        return nil
    }

    private func extractSubjects(from raw: Any?) -> [String] {
        guard let array = raw as? [Any] else { return [] }
        return array.compactMap { item in
            if let string = item as? String { return string.trimmedNonEmpty }
            if let object = item as? [String: Any] { return (object["name"] as? String)?.trimmedNonEmpty }
            return nil
        }
        .prefix(4)
        .map { $0 }
    }

    private func extractOPDS2Cover(
        images: Any?,
        links: [[String: Any]],
        baseURL: URL
    ) -> URL? {
        if let imageObjects = images as? [[String: Any]] {
            for image in imageObjects {
                if let href = image["href"] as? String, !href.isEmpty {
                    return absoluteURL(href, relativeTo: baseURL)
                }
            }
        }

        for link in links {
            let rels = relList(from: link["rel"])
            if rels.contains("cover") || rels.contains(where: { $0.contains("/image") }) {
                if let href = link["href"] as? String, !href.isEmpty {
                    return absoluteURL(href, relativeTo: baseURL)
                }
            }
        }
        return nil
    }

    private func extractAlternateURL(
        from links: [[String: Any]],
        baseURL: URL
    ) -> URL? {
        for link in links {
            let rels = relList(from: link["rel"])
            if rels.contains("alternate"),
               let type = link["type"] as? String,
               type == "text/html",
               let href = link["href"] as? String,
               !href.isEmpty {
                return absoluteURL(href, relativeTo: baseURL)
            }
        }
        return nil
    }

    private func extractOPDS1Cover(entry: XMLElement, baseURL: URL) -> URL? {
        let links = (try? entry.nodes(forXPath: "./*[local-name()='link']")) ?? []
        for node in links {
            guard let link = node as? XMLElement else { continue }
            let rel = link.attribute(forName: "rel")?.stringValue ?? ""
            let href = link.attribute(forName: "href")?.stringValue
            if rel.contains("/image") || rel.contains("/thumbnail"),
               let href, !href.isEmpty {
                return absoluteURL(href, relativeTo: baseURL)
            }
        }
        return nil
    }

    private func extractOPDS1AlternateURL(entry: XMLElement, baseURL: URL) -> URL? {
        let links = (try? entry.nodes(forXPath: "./*[local-name()='link']")) ?? []
        for node in links {
            guard let link = node as? XMLElement else { continue }
            let rel = link.attribute(forName: "rel")?.stringValue
            let type = link.attribute(forName: "type")?.stringValue
            let href = link.attribute(forName: "href")?.stringValue
            if rel == "alternate", type == "text/html", let href, !href.isEmpty {
                return absoluteURL(href, relativeTo: baseURL)
            }
        }
        return nil
    }

    private func firstString(in element: XMLElement, xpath: String) -> String? {
        let nodes = try? element.nodes(forXPath: xpath)
        return nodes?
            .compactMap { $0.stringValue?.trimmedNonEmpty }
            .first
    }

    private func absoluteURL(_ raw: String, relativeTo baseURL: URL) -> URL {
        URL(string: raw, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }

    private func absoluteURLString(_ raw: String, relativeTo baseURL: URL) -> String {
        absoluteURL(raw, relativeTo: baseURL).absoluteString
    }

    private func slugify(_ title: String) -> String {
        let cleaned = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return cleaned.isEmpty ? "moku-book" : cleaned
    }

    private func fileExtension(
        for acquisition: DiscoverCatalogAcquisition,
        preferredName: String
    ) -> String {
        let urlExtension = acquisition.url.pathExtension.lowercased()
        if BookFormat.allExtensions.contains(urlExtension) {
            return urlExtension
        }

        let nameExtension = URL(fileURLWithPath: preferredName).pathExtension.lowercased()
        if BookFormat.allExtensions.contains(nameExtension) {
            return nameExtension
        }

        return switch acquisition.format {
        case .epub: "epub"
        case .pdf: "pdf"
        case .txt: "txt"
        case .cbz: "cbz"
        case .html: "html"
        }
    }

    private func looksLikeHTMLResponse(contentType: String, data: Data) -> Bool {
        if contentType.contains("text/html") || contentType.contains("application/xhtml+xml") {
            return true
        }

        let prefix = String(decoding: data.prefix(256), as: UTF8.self).lowercased()
        return prefix.contains("<html") || prefix.contains("<!doctype html")
    }

    private func extractFollowUpDownloadURL(from html: String, baseURL: URL) -> URL? {
        if let match = html.firstMatch(
            for: #"http-equiv=["']refresh["'][^>]*content=["'][^"']*url=([^"']+)"#,
            options: [.caseInsensitive]
        ), let target = match.trimmedNonEmpty {
            return absoluteURL(target, relativeTo: baseURL)
        }

        if baseURL.host()?.contains("standardebooks.org") == true,
           var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
           !(components.queryItems ?? []).contains(where: { $0.name == "source" }) {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "source", value: "download"))
            components.queryItems = items
            return components.url
        }

        return nil
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func firstMatch(for pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              let captureRange = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[captureRange])
    }
}

private struct ResolvedDownload {
    let data: Data
    let finalURL: URL
}

private extension URL {
    func host() -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.host
    }
}
