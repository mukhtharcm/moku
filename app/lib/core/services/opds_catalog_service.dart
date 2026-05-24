import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/models.dart';

enum CatalogKind { openLibrary, gutenberg, custom }

enum CatalogProtocol { opds1, opds2 }

enum CatalogErrorCode {
  invalidCatalogInput,
  duplicateCatalog,
  catalogAuthenticationRequired,
  catalogAccessDenied,
  downloadRedirectLoop,
  downloadFailed,
  searchFailed,
  catalogNotSearchable,
  catalogLoadFailed,
  opds2MissingSearchLink,
  opds1MissingSearchDescription,
  catalogSearchDescriptionFailed,
  catalogSearchTemplateMissing,
}

class CatalogException extends Equatable implements Exception {
  final CatalogErrorCode code;
  final int? statusCode;

  const CatalogException(this.code, {this.statusCode});

  @override
  List<Object?> get props => [code, statusCode];
}

class CatalogSource extends Equatable {
  final String id;
  final String title;
  final String url;
  final CatalogKind kind;
  final CatalogProtocol protocol;
  final String? searchTemplate;

  const CatalogSource({
    required this.id,
    required this.title,
    required this.url,
    required this.kind,
    required this.protocol,
    this.searchTemplate,
  });

  bool get isCustom => kind == CatalogKind.custom;
  bool get supportsSearch =>
      kind == CatalogKind.openLibrary ||
      (searchTemplate != null && searchTemplate!.trim().isNotEmpty);

  Uri get uri => Uri.parse(url);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'kind': kind.name,
    'protocol': protocol.name,
    'searchTemplate': searchTemplate,
  };

  factory CatalogSource.fromJson(Map<String, dynamic> json) {
    return CatalogSource(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      kind: CatalogKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => CatalogKind.custom,
      ),
      protocol: CatalogProtocol.values.firstWhere(
        (value) => value.name == json['protocol'],
        orElse: () => CatalogProtocol.opds2,
      ),
      searchTemplate: json['searchTemplate'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, title, url, kind, protocol, searchTemplate];
}

class CatalogNavigationEntry extends Equatable {
  final String id;
  final String title;
  final String? subtitle;
  final Uri uri;

  const CatalogNavigationEntry({
    required this.id,
    required this.title,
    required this.uri,
    this.subtitle,
  });

  @override
  List<Object?> get props => [id, title, subtitle, uri];
}

class CatalogBrowsePage extends Equatable {
  final String title;
  final Uri? uri;
  final List<CatalogNavigationEntry> navigationEntries;
  final List<CatalogBook> books;

  const CatalogBrowsePage({
    required this.title,
    this.uri,
    this.navigationEntries = const [],
    this.books = const [],
  });

  bool get isEmpty => navigationEntries.isEmpty && books.isEmpty;

  @override
  List<Object?> get props => [title, uri, navigationEntries, books];
}

class CatalogAcquisition extends Equatable {
  final Uri url;
  final String mediaType;
  final BookFormat format;
  final String? title;

  const CatalogAcquisition({
    required this.url,
    required this.mediaType,
    required this.format,
    this.title,
  });

  @override
  List<Object?> get props => [url, mediaType, format, title];
}

class CatalogBook extends Equatable {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String? coverUrl;
  final String? yearLabel;
  final List<String> subjects;
  final String? externalUrl;
  final String catalogId;
  final String catalogTitle;
  final List<CatalogAcquisition> acquisitions;

  const CatalogBook({
    required this.id,
    required this.title,
    required this.author,
    required this.catalogId,
    required this.catalogTitle,
    required this.acquisitions,
    this.description,
    this.coverUrl,
    this.yearLabel,
    this.subjects = const [],
    this.externalUrl,
  });

  CatalogAcquisition get preferredAcquisition => acquisitions.first;

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    description,
    coverUrl,
    yearLabel,
    subjects,
    externalUrl,
    catalogId,
    catalogTitle,
    acquisitions,
  ];
}

class OpdsCatalogService {
  static const _prefsKey = 'discover_custom_catalogs';

  final http.Client _client;

  OpdsCatalogService({http.Client? client}) : _client = client ?? http.Client();

  static const List<CatalogSource> _builtInCatalogs = [
    CatalogSource(
      id: 'open-library',
      title: '',
      url: 'https://openlibrary.org/opds/',
      kind: CatalogKind.openLibrary,
      protocol: CatalogProtocol.opds2,
    ),
    CatalogSource(
      id: 'project-gutenberg',
      title: '',
      url: 'https://www.gutenberg.org/ebooks/search.opds/',
      kind: CatalogKind.gutenberg,
      protocol: CatalogProtocol.opds1,
      searchTemplate:
          'https://www.gutenberg.org/ebooks/search.opds/?query={searchTerms}',
    ),
  ];

  Future<List<CatalogSource>> loadCatalogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    final custom = raw
        .map(
          (item) =>
              CatalogSource.fromJson(json.decode(item) as Map<String, dynamic>),
        )
        .toList();
    return [..._builtInCatalogs, ...custom];
  }

  Future<CatalogSource> addCustomCatalog({
    required String title,
    required String url,
  }) async {
    final trimmedTitle = title.trim();
    final normalizedUrl = _normalizeUrl(url);
    if (trimmedTitle.isEmpty || normalizedUrl == null) {
      throw const CatalogException(CatalogErrorCode.invalidCatalogInput);
    }

    final prepared = await _prepareCustomCatalog(
      title: trimmedTitle,
      rootUrl: normalizedUrl,
    );

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefsKey) ?? const [];
    final decoded = existing
        .map(
          (item) =>
              CatalogSource.fromJson(json.decode(item) as Map<String, dynamic>),
        )
        .toList();

    if (decoded.any((item) => item.url == prepared.url)) {
      throw const CatalogException(CatalogErrorCode.duplicateCatalog);
    }

    final updated = [
      ...decoded,
      prepared,
    ].map((item) => json.encode(item.toJson())).toList();
    await prefs.setStringList(_prefsKey, updated);
    return prepared;
  }

  Future<void> removeCustomCatalog(String catalogId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefsKey) ?? const [];
    final filtered = existing.where((item) {
      final decoded = CatalogSource.fromJson(
        json.decode(item) as Map<String, dynamic>,
      );
      return decoded.id != catalogId;
    }).toList();
    await prefs.setStringList(_prefsKey, filtered);
  }

  Future<List<CatalogBook>> searchBooks(
    CatalogSource catalog,
    String query,
  ) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return const [];

    switch (catalog.kind) {
      case CatalogKind.openLibrary:
        return _searchOpenLibrary(catalog, trimmedQuery);
      case CatalogKind.gutenberg:
      case CatalogKind.custom:
        return switch (catalog.protocol) {
          CatalogProtocol.opds1 => _searchOpds1(catalog, trimmedQuery),
          CatalogProtocol.opds2 => _searchOpds2(catalog, trimmedQuery),
        };
    }
  }

  Future<CatalogBrowsePage> loadCatalogPage(
    CatalogSource catalog, {
    Uri? pageUri,
  }) async {
    final uri = pageUri ?? catalog.uri;

    switch (catalog.kind) {
      case CatalogKind.openLibrary:
        return _browseOpds2(catalog, uri);
      case CatalogKind.gutenberg:
      case CatalogKind.custom:
        return switch (catalog.protocol) {
          CatalogProtocol.opds1 => _browseOpds1(catalog, uri),
          CatalogProtocol.opds2 => _browseOpds2(catalog, uri),
        };
    }
  }

  Future<String> downloadAcquisition(
    CatalogAcquisition acquisition, {
    required String suggestedName,
  }) async {
    final resolved = await _downloadResolvedAcquisition(
      acquisition.url,
      expectedFormat: acquisition.format,
    );

    final tempDir = await getTemporaryDirectory();
    final extension = _extensionFor(
      acquisition,
      preferredName: resolved.finalUri.pathSegments.isNotEmpty
          ? resolved.finalUri.pathSegments.last
          : suggestedName,
    );
    final safeName = suggestedName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final fileName =
        '${safeName.isEmpty ? 'moku-book' : safeName}-${DateTime.now().microsecondsSinceEpoch}.$extension';
    final path = p.join(tempDir.path, fileName);
    final file = File(path);
    await file.writeAsBytes(resolved.bytes);
    return path;
  }

  Future<_ResolvedDownload> _downloadResolvedAcquisition(
    Uri url, {
    required BookFormat expectedFormat,
    int depth = 0,
  }) async {
    if (depth > 3) {
      throw const CatalogException(CatalogErrorCode.downloadRedirectLoop);
    }

    final response = await _client.get(
      url,
      headers: {
        'Accept':
            'application/epub+zip,application/pdf,text/plain,text/html,*/*',
        'User-Agent': 'Moku/1.0',
      },
    );
    if (response.statusCode != 200) {
      throw CatalogException(
        CatalogErrorCode.downloadFailed,
        statusCode: response.statusCode,
      );
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final bodyBytes = response.bodyBytes;
    final responseUri = response.request?.url ?? url;

    if (expectedFormat != BookFormat.html &&
        _looksLikeHtmlResponse(contentType, bodyBytes)) {
      final html = utf8.decode(bodyBytes, allowMalformed: true);
      final followUp = _extractFollowUpDownloadUrl(html, responseUri);
      if (followUp != null && followUp != responseUri) {
        return _downloadResolvedAcquisition(
          followUp,
          expectedFormat: expectedFormat,
          depth: depth + 1,
        );
      }
    }

    return _ResolvedDownload(bytes: bodyBytes, finalUri: responseUri);
  }

  Future<List<CatalogBook>> _searchOpenLibrary(
    CatalogSource catalog,
    String query,
  ) async {
    final uri = Uri.parse('https://openlibrary.org/opds/search').replace(
      queryParameters: {'query': query, 'mode': 'open_access', 'limit': '8'},
    );
    final response = await _client
        .get(uri, headers: {'User-Agent': 'Moku/1.0'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw CatalogException(
        _statusToCatalogErrorCode(
          response.statusCode,
          fallback: CatalogErrorCode.searchFailed,
        ),
        statusCode: response.statusCode,
      );
    }
    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    return _parseOpenLibraryFeed(
      catalog: catalog,
      baseUri: uri,
      jsonMap: jsonMap,
    );
  }

  Future<List<CatalogBook>> _searchOpds2(
    CatalogSource catalog,
    String query,
  ) async {
    final template = catalog.searchTemplate;
    if (template == null || template.isEmpty) {
      throw const CatalogException(CatalogErrorCode.catalogNotSearchable);
    }

    final uri = _expandSearchTemplate(template, query);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw CatalogException(
        _statusToCatalogErrorCode(
          response.statusCode,
          fallback: CatalogErrorCode.searchFailed,
        ),
        statusCode: response.statusCode,
      );
    }

    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    return _parseOpds2Feed(catalog: catalog, baseUri: uri, jsonMap: jsonMap);
  }

  Future<List<CatalogBook>> _searchOpds1(
    CatalogSource catalog,
    String query,
  ) async {
    final template = catalog.searchTemplate;
    if (template == null || template.isEmpty) {
      throw const CatalogException(CatalogErrorCode.catalogNotSearchable);
    }

    final uri = _expandSearchTemplate(template, query);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw CatalogException(
        _statusToCatalogErrorCode(
          response.statusCode,
          fallback: CatalogErrorCode.searchFailed,
        ),
        statusCode: response.statusCode,
      );
    }

    final document = XmlDocument.parse(response.body);
    return _parseOpds1Feed(catalog: catalog, baseUri: uri, document: document);
  }

  Future<CatalogBrowsePage> _browseOpds1(CatalogSource catalog, Uri uri) async {
    final response = await _client
        .get(uri, headers: {'User-Agent': 'Moku/1.0'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw CatalogException(
        _statusToCatalogErrorCode(
          response.statusCode,
          fallback: CatalogErrorCode.catalogLoadFailed,
        ),
        statusCode: response.statusCode,
      );
    }

    final document = XmlDocument.parse(response.body);
    final books = <CatalogBook>[];
    final navigationEntries = <CatalogNavigationEntry>[];

    for (final entry in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'entry',
    )) {
      final acquisitions = _parseOpds1Acquisitions(entry, uri);
      final title = _childText(entry, 'title');
      if (title == null || title.isEmpty) continue;

      if (acquisitions.isNotEmpty) {
        final authorElement = _firstChild(entry, 'author');
        final authorName = authorElement == null
            ? null
            : _childText(authorElement, 'name');

        books.add(
          CatalogBook(
            id: _childText(entry, 'id') ?? acquisitions.first.url.toString(),
            title: title,
            author: authorName?.trim() ?? '',
            description: _childText(entry, 'content'),
            coverUrl: _extractOpds1Cover(entry, uri)?.toString(),
            yearLabel: _childText(entry, 'published')?.split('-').first,
            externalUrl: _extractOpds1AlternateLink(entry, uri)?.toString(),
            catalogId: catalog.id,
            catalogTitle: catalog.title,
            acquisitions: acquisitions,
          ),
        );
        continue;
      }

      final subsectionUri = _extractOpds1SubsectionCatalogUri(entry, uri);
      if (subsectionUri == null) continue;

      navigationEntries.add(
        CatalogNavigationEntry(
          id: _childText(entry, 'id') ?? subsectionUri.toString(),
          title: title,
          subtitle: _childText(entry, 'summary') ?? _childText(entry, 'content'),
          uri: subsectionUri,
        ),
      );
    }

    return CatalogBrowsePage(
      title: _extractOpds1FeedTitle(document) ?? catalog.title,
      uri: uri,
      navigationEntries: navigationEntries,
      books: books,
    );
  }

  Future<CatalogBrowsePage> _browseOpds2(CatalogSource catalog, Uri uri) async {
    final response = await _client
        .get(uri, headers: {'User-Agent': 'Moku/1.0'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw CatalogException(
        _statusToCatalogErrorCode(
          response.statusCode,
          fallback: CatalogErrorCode.catalogLoadFailed,
        ),
        statusCode: response.statusCode,
      );
    }

    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    final books = catalog.kind == CatalogKind.openLibrary
        ? await _parseOpenLibraryFeed(
            catalog: catalog,
            baseUri: uri,
            jsonMap: jsonMap,
          )
        : _parseOpds2Feed(catalog: catalog, baseUri: uri, jsonMap: jsonMap);

    return CatalogBrowsePage(
      title: _extractOpds2FeedTitle(jsonMap) ?? catalog.title,
      uri: uri,
      navigationEntries: _extractOpds2NavigationEntries(jsonMap, uri),
      books: books,
    );
  }

  Future<CatalogSource> _prepareCustomCatalog({
    required String title,
    required String rootUrl,
  }) async {
    final rootUri = Uri.parse(rootUrl);
    final response = await _client.get(rootUri);
    if (response.statusCode != 200) {
      throw CatalogException(
        _statusToCatalogErrorCode(
          response.statusCode,
          fallback: CatalogErrorCode.catalogLoadFailed,
        ),
        statusCode: response.statusCode,
      );
    }

    final body = response.body.trimLeft();
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';

    if (contentType.contains('application/opds+json') || body.startsWith('{')) {
      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      final searchTemplate = _extractOpds2SearchTemplate(jsonMap, rootUri);
      return CatalogSource(
        id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        url: rootUri.toString(),
        kind: CatalogKind.custom,
        protocol: CatalogProtocol.opds2,
        searchTemplate: searchTemplate,
      );
    }

    final document = XmlDocument.parse(response.body);
    final openSearchUri = _extractOpds1OpenSearchUri(document, rootUri);
    String? resolvedSearchTemplate;
    if (openSearchUri != null) {
      final openSearchResponse = await _client.get(openSearchUri);
      if (openSearchResponse.statusCode == 200) {
        final openSearchDocument = XmlDocument.parse(openSearchResponse.body);
        final searchTemplate = _extractOpenSearchTemplate(openSearchDocument);
        if (searchTemplate != null) {
          resolvedSearchTemplate = _resolveTemplateAgainstBase(
            rootUri,
            searchTemplate,
          );
        }
      }
    }

    return CatalogSource(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      url: rootUri.toString(),
      kind: CatalogKind.custom,
      protocol: CatalogProtocol.opds1,
      searchTemplate: resolvedSearchTemplate,
    );
  }

  Future<List<CatalogBook>> _parseOpenLibraryFeed({
    required CatalogSource catalog,
    required Uri baseUri,
    required Map<String, dynamic> jsonMap,
  }) async {
    final publications = <Map<String, dynamic>>[
      ..._readPublications(jsonMap['publications']),
      ..._readGroupPublications(jsonMap['groups']),
    ].take(8).toList();

    final resolved = await Future.wait(
      publications.map(
        (publication) => _parseOpenLibraryPublication(
          catalog: catalog,
          baseUri: baseUri,
          publication: publication,
        ),
      ),
    );

    return resolved.whereType<CatalogBook>().toList();
  }

  Future<CatalogBook?> _parseOpenLibraryPublication({
    required CatalogSource catalog,
    required Uri baseUri,
    required Map<String, dynamic> publication,
  }) async {
    final metadata =
        publication['metadata'] as Map<String, dynamic>? ?? const {};
    final links = publication['links'] as List<dynamic>? ?? const [];
    final images = publication['images'] as List<dynamic>? ?? const [];
    final title = (metadata['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;

    var acquisitions = _parseOpds2Acquisitions(links, baseUri);
    Uri? externalUrl = _extractAlternateLink(links, baseUri);

    if (acquisitions.isEmpty) {
      final manifestUrls = _extractPublicationManifestUrls(links, baseUri);
      for (final manifestUri in manifestUrls) {
        final manifest = await _loadOpdsPublicationManifest(manifestUri);
        if (manifest == null) continue;

        acquisitions = _parseOpdsPublicationManifestAcquisitions(
          manifest,
          manifestUri,
        );
        externalUrl ??= _extractAlternateLink(
          manifest['links'] as List<dynamic>? ?? const [],
          manifestUri,
        );

        if (acquisitions.isNotEmpty) break;
      }
    }

    if (acquisitions.isEmpty) return null;

    return CatalogBook(
      id:
          (publication['id'] as String?) ??
          (metadata['identifier'] as String?) ??
          acquisitions.first.url.toString(),
      title: title,
      author: _extractOpds2Author(metadata['author']).trim(),
      description: _extractDescription(metadata['description']),
      coverUrl: _extractOpds2Cover(images, links, baseUri)?.toString(),
      yearLabel: _extractYear(metadata),
      subjects: _extractSubjects(metadata['subject']),
      externalUrl: externalUrl?.toString(),
      catalogId: catalog.id,
      catalogTitle: catalog.title,
      acquisitions: acquisitions,
    );
  }

  List<CatalogBook> _parseOpds2Feed({
    required CatalogSource catalog,
    required Uri baseUri,
    required Map<String, dynamic> jsonMap,
  }) {
    final publications = <Map<String, dynamic>>[
      ..._readPublications(jsonMap['publications']),
      ..._readGroupPublications(jsonMap['groups']),
    ];

    return publications
        .map((publication) {
          final metadata =
              publication['metadata'] as Map<String, dynamic>? ?? const {};
          final links = publication['links'] as List<dynamic>? ?? const [];
          final acquisitions = _parseOpds2Acquisitions(links, baseUri);
          if (acquisitions.isEmpty) return null;

          final images = publication['images'] as List<dynamic>? ?? const [];
          final cover = _extractOpds2Cover(images, links, baseUri);
          final author = _extractOpds2Author(metadata['author']);
          final title = (metadata['title'] as String?)?.trim();
          if (title == null || title.isEmpty) return null;

          return CatalogBook(
            id:
                (publication['id'] as String?) ??
                (metadata['identifier'] as String?) ??
                acquisitions.first.url.toString(),
            title: title,
            author: author.trim(),
            description: _extractDescription(metadata['description']),
            coverUrl: cover?.toString(),
            yearLabel: _extractYear(metadata),
            subjects: _extractSubjects(metadata['subject']),
            externalUrl: _extractAlternateLink(links, baseUri)?.toString(),
            catalogId: catalog.id,
            catalogTitle: catalog.title,
            acquisitions: acquisitions,
          );
        })
        .whereType<CatalogBook>()
        .toList();
  }

  Future<Map<String, dynamic>?> _loadOpdsPublicationManifest(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'Moku/1.0'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return null;
  }

  Future<List<CatalogBook>> _parseOpds1Feed({
    required CatalogSource catalog,
    required Uri baseUri,
    required XmlDocument document,
    int depth = 0,
    int maxResults = 8,
  }) async {
    final results = <CatalogBook>[];
    for (final entry in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'entry',
    )) {
      if (results.length >= maxResults) break;

      final acquisitions = _parseOpds1Acquisitions(entry, baseUri);
      if (acquisitions.isNotEmpty) {
        final title = _childText(entry, 'title');
        if (title == null || title.isEmpty) continue;

        final authorElement = _firstChild(entry, 'author');
        final authorName = authorElement == null
            ? null
            : _childText(authorElement, 'name');

        results.add(
          CatalogBook(
            id: _childText(entry, 'id') ?? acquisitions.first.url.toString(),
            title: title,
            author: authorName?.trim() ?? '',
            description: _childText(entry, 'content'),
            coverUrl: _extractOpds1Cover(entry, baseUri)?.toString(),
            yearLabel: _childText(entry, 'published')?.split('-').first,
            externalUrl: _extractOpds1AlternateLink(entry, baseUri)?.toString(),
            catalogId: catalog.id,
            catalogTitle: catalog.title,
            acquisitions: acquisitions,
          ),
        );
        continue;
      }

      final subsectionUri = _extractOpds1SubsectionCatalogUri(entry, baseUri);
      if (subsectionUri == null || depth >= 1) continue;

      final nestedResults = await _loadOpds1NestedFeed(
        catalog: catalog,
        uri: subsectionUri,
        depth: depth + 1,
        maxResults: maxResults - results.length,
      );
      results.addAll(nestedResults);
    }
    return results;
  }

  Future<List<CatalogBook>> _loadOpds1NestedFeed({
    required CatalogSource catalog,
    required Uri uri,
    required int depth,
    required int maxResults,
  }) async {
    if (maxResults <= 0) return const [];

    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'Moku/1.0'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return const [];

      final document = XmlDocument.parse(response.body);
      return _parseOpds1Feed(
        catalog: catalog,
        baseUri: uri,
        document: document,
        depth: depth,
        maxResults: maxResults,
      );
    } catch (_) {
      return const [];
    }
  }

  List<CatalogAcquisition> _parseOpds2Acquisitions(
    List<dynamic> links,
    Uri baseUri,
  ) {
    final acquisitions = links
        .whereType<Map<String, dynamic>>()
        .map((link) {
          final relValues = _asRelList(link['rel']);
          if (!relValues.any(_isAcquisitionRelation)) return null;

          final mediaType = (link['type'] as String?)?.trim();
          final format = _formatFromMediaType(mediaType);
          if (format == null) return null;

          final href = link['href'] as String?;
          if (href == null || href.isEmpty) return null;

          return CatalogAcquisition(
            url: baseUri.resolve(href),
            mediaType: mediaType!,
            format: format,
            title: link['title'] as String?,
          );
        })
        .whereType<CatalogAcquisition>()
        .toList();

    acquisitions.sort(_compareAcquisitions);
    return acquisitions;
  }

  List<CatalogAcquisition> _parseOpdsPublicationManifestAcquisitions(
    Map<String, dynamic> manifest,
    Uri baseUri,
  ) {
    final candidates = <dynamic>[
      ...(manifest['links'] as List<dynamic>? ?? const []),
      ...(manifest['readingOrder'] as List<dynamic>? ?? const []),
      ...(manifest['resources'] as List<dynamic>? ?? const []),
    ];

    return _parseOpds2Acquisitions(candidates, baseUri);
  }

  List<CatalogAcquisition> _parseOpds1Acquisitions(
    XmlElement entry,
    Uri baseUri,
  ) {
    final acquisitions = entry.children
        .whereType<XmlElement>()
        .where((element) {
          return element.name.local == 'link' &&
              _isAcquisitionRelation(element.getAttribute('rel'));
        })
        .map((element) {
          final href = element.getAttribute('href');
          final mediaType = element.getAttribute('type');
          final format = _formatFromMediaType(mediaType);
          if (href == null || mediaType == null || format == null) return null;

          return CatalogAcquisition(
            url: baseUri.resolve(href),
            mediaType: mediaType,
            format: format,
            title: element.getAttribute('title'),
          );
        })
        .whereType<CatalogAcquisition>()
        .toList();

    acquisitions.sort(_compareAcquisitions);
    return acquisitions;
  }

  String? _extractOpds2SearchTemplate(
    Map<String, dynamic> jsonMap,
    Uri baseUri,
  ) {
    final links = jsonMap['links'] as List<dynamic>? ?? const [];
    for (final link in links.whereType<Map<String, dynamic>>()) {
      final relValues = _asRelList(link['rel']);
      final href = link['href'] as String?;
      if (href == null || href.isEmpty) continue;
      if (relValues.contains('search')) {
        return _resolveTemplateAgainstBase(baseUri, href);
      }
    }
    return null;
  }

  String? _extractOpds2FeedTitle(Map<String, dynamic> jsonMap) {
    final metadata = jsonMap['metadata'];
    if (metadata is Map<String, dynamic>) {
      final title = metadata['title'];
      if (title is String && title.trim().isNotEmpty) return title.trim();
    }

    final title = jsonMap['title'];
    if (title is String && title.trim().isNotEmpty) return title.trim();
    return null;
  }

  Uri? _extractOpds1OpenSearchUri(XmlDocument document, Uri baseUri) {
    for (final link in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'link',
    )) {
      final rel = link.getAttribute('rel');
      final type = link.getAttribute('type');
      final href = link.getAttribute('href');
      if (rel == 'search' &&
          type?.contains('application/opensearchdescription+xml') == true &&
          href != null &&
          href.isNotEmpty) {
        return baseUri.resolve(href);
      }
    }
    return null;
  }

  String? _extractOpenSearchTemplate(XmlDocument document) {
    for (final urlElement in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'Url',
    )) {
      final type = urlElement.getAttribute('type') ?? '';
      if (type.contains('opds-catalog') || type.contains('atom+xml')) {
        return urlElement.getAttribute('template');
      }
    }
    return document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'Url')
        .map((element) => element.getAttribute('template'))
        .whereType<String>()
        .firstOrNull;
  }

  List<Uri> _extractPublicationManifestUrls(List<dynamic> links, Uri baseUri) {
    return links
        .whereType<Map<String, dynamic>>()
        .where((link) {
          final type = (link['type'] as String?)?.trim().toLowerCase();
          return type == 'application/opds-publication+json';
        })
        .map((link) => link['href'] as String?)
        .whereType<String>()
        .where((href) => href.isNotEmpty)
        .map(baseUri.resolve)
        .toSet()
        .toList();
  }

  String? _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri.toString();
  }

  Uri _expandSearchTemplate(String template, String query) {
    var result = template;
    final encoded = Uri.encodeQueryComponent(query);

    result = result.replaceAll('{searchTerms}', encoded);
    result = result.replaceAll('{query}', encoded);

    final queryExpansion = RegExp(r'\{\?([^}]+)\}');
    result = result.replaceAllMapped(queryExpansion, (match) {
      final params = match.group(1)!.split(',');
      final values = <String, String>{};
      for (final param in params) {
        final key = param.trim();
        if (key == 'query' || key == 'q' || key == 'searchTerms') {
          values[key == 'searchTerms' ? 'query' : key] = query;
        }
      }
      if (values.isEmpty) return '';
      return '?${Uri(queryParameters: values).query}';
    });

    result = result.replaceAllMapped(RegExp(r'\{&([^}]+)\}'), (match) {
      final params = match.group(1)!.split(',');
      final values = <String, String>{};
      for (final param in params) {
        final key = param.trim();
        if (key == 'query' || key == 'q' || key == 'searchTerms') {
          values[key == 'searchTerms' ? 'query' : key] = query;
        }
      }
      if (values.isEmpty) return '';
      final prefix = result.contains('?') ? '&' : '?';
      return '$prefix${Uri(queryParameters: values).query}';
    });

    result = result.replaceAll(RegExp(r'\{[^}]+\}'), '');
    return Uri.parse(result);
  }

  BookFormat? _formatFromMediaType(String? mediaType) {
    if (mediaType == null) return null;
    final normalized = mediaType.split(';').first.trim().toLowerCase();
    return switch (normalized) {
      'application/epub+zip' => BookFormat.epub,
      'application/pdf' => BookFormat.pdf,
      'text/plain' => BookFormat.txt,
      'text/html' || 'application/xhtml+xml' => BookFormat.html,
      _ => null,
    };
  }

  int _compareAcquisitions(CatalogAcquisition a, CatalogAcquisition b) =>
      _formatPriority(a.format).compareTo(_formatPriority(b.format));

  int _formatPriority(BookFormat format) => switch (format) {
    BookFormat.epub => 0,
    BookFormat.pdf => 1,
    BookFormat.html => 2,
    BookFormat.txt => 3,
    BookFormat.cbz => 4,
  };

  bool _isAcquisitionRelation(String? rel) =>
      rel != null && rel.startsWith('http://opds-spec.org/acquisition');

  List<String> _asRelList(Object? raw) {
    if (raw is String) return [raw];
    if (raw is List) return raw.whereType<String>().toList();
    return const [];
  }

  List<Map<String, dynamic>> _readPublications(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _readGroupPublications(Object? raw) {
    if (raw is! List) return const [];
    final results = <Map<String, dynamic>>[];
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      results.addAll(_readPublications(item['publications']));
    }
    return results;
  }

  List<CatalogNavigationEntry> _extractOpds2NavigationEntries(
    Map<String, dynamic> jsonMap,
    Uri baseUri,
  ) {
    final entries = <CatalogNavigationEntry>[];
    final seen = <String>{};

    void addEntry({
      required String title,
      required Uri uri,
      String? subtitle,
      String? id,
    }) {
      final trimmedTitle = title.trim();
      if (trimmedTitle.isEmpty) return;
      final key = uri.toString();
      if (!seen.add(key)) return;
      entries.add(
        CatalogNavigationEntry(
          id: id ?? key,
          title: trimmedTitle,
          subtitle: subtitle?.trim().isEmpty ?? true ? null : subtitle?.trim(),
          uri: uri,
        ),
      );
    }

    final navigation = jsonMap['navigation'];
    if (navigation is List) {
      for (final item in navigation.whereType<Map<String, dynamic>>()) {
        final title = (item['title'] as String?)?.trim();
        final href = (item['href'] as String?)?.trim();
        final links = item['links'] as List<dynamic>? ?? const [];
        final target = href?.isNotEmpty == true
            ? baseUri.resolve(href!)
            : _extractBrowsableOpds2Link(links, baseUri);
        if (title == null || title.isEmpty || target == null) continue;
        addEntry(
          title: title,
          uri: target,
          id: item['id'] as String?,
          subtitle: _extractDescription(item['summary']),
        );
      }
    }

    for (final link in (jsonMap['links'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()) {
      if (!_isBrowsableOpds2Link(link)) continue;
      final target = _resolveHref(link['href'] as String?, baseUri);
      final title = (link['title'] as String?)?.trim();
      if (target == null || title == null || title.isEmpty) continue;
      addEntry(title: title, uri: target);
    }

    final groups = jsonMap['groups'];
    if (groups is List) {
      for (final group in groups.whereType<Map<String, dynamic>>()) {
        final metadata =
            group['metadata'] as Map<String, dynamic>? ?? const {};
        final title = (metadata['title'] as String?)?.trim();
        final target = _extractBrowsableOpds2Link(
          group['links'] as List<dynamic>? ?? const [],
          baseUri,
        );
        if (title == null || title.isEmpty || target == null) continue;
        addEntry(
          title: title,
          uri: target,
          subtitle: _extractDescription(metadata['description']),
        );
      }
    }

    return entries;
  }

  String _extractOpds2Author(Object? raw) {
    if (raw is String) return raw;
    if (raw is Map<String, dynamic>) return (raw['name'] as String?) ?? '';
    if (raw is List) {
      return raw
          .map((item) {
            if (item is String) return item;
            if (item is Map<String, dynamic>) {
              return item['name'] as String? ?? '';
            }
            return '';
          })
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return '';
  }

  String? _extractDescription(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is Map<String, dynamic>) {
      for (final key in ['value', 'text', 'html']) {
        final value = raw[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  String? _extractYear(Map<String, dynamic> metadata) {
    for (final key in ['published', 'modified', 'issued']) {
      final value = metadata[key];
      if (value is String && value.length >= 4) {
        return value.substring(0, 4);
      }
    }
    return null;
  }

  List<String> _extractSubjects(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is String) return item;
          if (item is Map<String, dynamic>) {
            return item['name'] as String? ?? '';
          }
          return '';
        })
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList();
  }

  Uri? _extractOpds2Cover(
    List<dynamic> images,
    List<dynamic> links,
    Uri baseUri,
  ) {
    for (final image in images.whereType<Map<String, dynamic>>()) {
      final href = image['href'] as String?;
      if (href != null && href.isNotEmpty) return baseUri.resolve(href);
    }

    for (final link in links.whereType<Map<String, dynamic>>()) {
      final relValues = _asRelList(link['rel']);
      final href = link['href'] as String?;
      if (href != null &&
          href.isNotEmpty &&
          relValues.any((item) => item == 'cover' || item.contains('/image'))) {
        return baseUri.resolve(href);
      }
    }
    return null;
  }

  Uri? _extractAlternateLink(List<dynamic> links, Uri baseUri) {
    for (final link in links.whereType<Map<String, dynamic>>()) {
      final relValues = _asRelList(link['rel']);
      final href = link['href'] as String?;
      final type = link['type'] as String?;
      if (href != null &&
          href.isNotEmpty &&
          relValues.contains('alternate') &&
          type == 'text/html') {
        return baseUri.resolve(href);
      }
    }
    return null;
  }

  Uri? _extractBrowsableOpds2Link(List<dynamic> links, Uri baseUri) {
    for (final link in links.whereType<Map<String, dynamic>>()) {
      if (!_isBrowsableOpds2Link(link)) continue;
      final uri = _resolveHref(link['href'] as String?, baseUri);
      if (uri != null) return uri;
    }
    return null;
  }

  bool _isBrowsableOpds2Link(Map<String, dynamic> link) {
    final relValues = _asRelList(link['rel']);
    if (relValues.contains('self') || relValues.contains('search')) {
      return false;
    }
    if (relValues.any(_isAcquisitionRelation)) return false;
    if (relValues.any((item) => item == 'cover' || item.contains('/image'))) {
      return false;
    }

    final type = (link['type'] as String?)?.toLowerCase() ?? '';
    return type.contains('opds+json') || type.contains('opds-catalog');
  }

  Uri? _extractOpds1Cover(XmlElement entry, Uri baseUri) {
    for (final link in entry.children.whereType<XmlElement>()) {
      if (link.name.local != 'link') continue;
      final rel = link.getAttribute('rel') ?? '';
      final href = link.getAttribute('href');
      if (href != null &&
          href.isNotEmpty &&
          (rel.contains('/image') || rel.contains('/thumbnail'))) {
        return baseUri.resolve(href);
      }
    }
    return null;
  }

  Uri? _extractOpds1AlternateLink(XmlElement entry, Uri baseUri) {
    for (final link in entry.children.whereType<XmlElement>()) {
      if (link.name.local != 'link') continue;
      final rel = link.getAttribute('rel');
      final type = link.getAttribute('type');
      final href = link.getAttribute('href');
      if (href != null &&
          href.isNotEmpty &&
          rel == 'alternate' &&
          type == 'text/html') {
        return baseUri.resolve(href);
      }
    }
    return null;
  }

  Uri? _extractOpds1SubsectionCatalogUri(XmlElement entry, Uri baseUri) {
    for (final link in entry.children.whereType<XmlElement>()) {
      if (link.name.local != 'link') continue;
      final rel = link.getAttribute('rel') ?? '';
      final type = link.getAttribute('type') ?? '';
      final href = link.getAttribute('href');
      if (rel != 'subsection' ||
          !type.contains('opds-catalog') ||
          href == null ||
          href.isEmpty) {
        continue;
      }

      final resolved = baseUri.resolve(href);
      return resolved;
    }
    return null;
  }

  String? _extractOpds1FeedTitle(XmlDocument document) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'title') continue;
      final text = element.innerText.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  XmlElement? _firstChild(XmlElement parent, String localName) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == localName) return child;
    }
    return null;
  }

  String? _childText(XmlElement parent, String localName) {
    final child = _firstChild(parent, localName);
    final text = child?.innerText.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _extensionFor(
    CatalogAcquisition acquisition, {
    required String preferredName,
  }) {
    final urlExtension = p
        .extension(acquisition.url.path)
        .replaceFirst('.', '')
        .toLowerCase();
    if (BookFormat.allExtensions.contains(urlExtension)) return urlExtension;

    final nameExtension = p
        .extension(preferredName)
        .replaceFirst('.', '')
        .toLowerCase();
    if (BookFormat.allExtensions.contains(nameExtension)) return nameExtension;

    return switch (acquisition.format) {
      BookFormat.epub => 'epub',
      BookFormat.pdf => 'pdf',
      BookFormat.txt => 'txt',
      BookFormat.html => 'html',
      BookFormat.cbz => 'cbz',
    };
  }

  bool _looksLikeHtmlResponse(String contentType, List<int> bytes) {
    if (contentType.contains('text/html') ||
        contentType.contains('application/xhtml+xml')) {
      return true;
    }

    final prefix = utf8
        .decode(bytes.take(256).toList(), allowMalformed: true)
        .toLowerCase();
    return prefix.contains('<html') || prefix.contains('<!doctype html');
  }

  Uri? _extractFollowUpDownloadUrl(String html, Uri baseUri) {
    final refreshMatch = RegExp(
      r'''http-equiv=["']refresh["'][^>]*content=["'][^"']*url=([^"']+)''',
      caseSensitive: false,
    ).firstMatch(html);
    if (refreshMatch != null) {
      final target = refreshMatch.group(1)?.trim();
      if (target != null && target.isNotEmpty) {
        return baseUri.resolve(target);
      }
    }

    if (baseUri.host.contains('standardebooks.org') &&
        !baseUri.queryParameters.containsKey('source')) {
      final query = Map<String, String>.from(baseUri.queryParameters)
        ..['source'] = 'download';
      return baseUri.replace(queryParameters: query);
    }

    return null;
  }

  String _resolveTemplateAgainstBase(Uri baseUri, String template) {
    const openToken = '__moku_open__';
    const closeToken = '__moku_close__';
    final protectedTemplate = template
        .replaceAll('{', openToken)
        .replaceAll('}', closeToken);
    return baseUri
        .resolve(protectedTemplate)
        .toString()
        .replaceAll(openToken, '{')
        .replaceAll(closeToken, '}');
  }

  Uri? _resolveHref(String? href, Uri baseUri) {
    if (href == null || href.trim().isEmpty) return null;
    return baseUri.resolve(href.trim());
  }

  CatalogErrorCode _statusToCatalogErrorCode(
    int statusCode, {
    required CatalogErrorCode fallback,
  }) {
    return switch (statusCode) {
      401 => CatalogErrorCode.catalogAuthenticationRequired,
      403 => CatalogErrorCode.catalogAccessDenied,
      _ => fallback,
    };
  }

  void dispose() {
    _client.close();
  }
}

class _ResolvedDownload {
  final List<int> bytes;
  final Uri finalUri;

  const _ResolvedDownload({required this.bytes, required this.finalUri});
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
