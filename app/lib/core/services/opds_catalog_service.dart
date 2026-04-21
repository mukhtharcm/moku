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

  String get formatSummary =>
      acquisitions.map((item) => item.format.displayName).toSet().join(' · ');

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
      title: 'Open Library',
      url: 'https://openlibrary.org/opds/',
      kind: CatalogKind.openLibrary,
      protocol: CatalogProtocol.opds2,
    ),
    CatalogSource(
      id: 'project-gutenberg',
      title: 'Project Gutenberg',
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
      throw Exception('Enter a valid title and URL.');
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
      throw Exception('That catalog is already added.');
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
      throw Exception('Download redirected too many times.');
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
      throw Exception('Download failed (${response.statusCode}).');
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
      queryParameters: {'query': query, 'mode': 'open_access', 'limit': '20'},
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Search failed (${response.statusCode}).');
    }
    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    return _parseOpds2Feed(catalog: catalog, baseUri: uri, jsonMap: jsonMap);
  }

  Future<List<CatalogBook>> _searchOpds2(
    CatalogSource catalog,
    String query,
  ) async {
    final template = catalog.searchTemplate;
    if (template == null || template.isEmpty) {
      throw Exception('This catalog does not expose a searchable OPDS feed.');
    }

    final uri = _expandSearchTemplate(template, query);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Search failed (${response.statusCode}).');
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
      throw Exception('This catalog does not expose a searchable OPDS feed.');
    }

    final uri = _expandSearchTemplate(template, query);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Search failed (${response.statusCode}).');
    }

    final document = XmlDocument.parse(response.body);
    return _parseOpds1Feed(catalog: catalog, baseUri: uri, document: document);
  }

  Future<CatalogSource> _prepareCustomCatalog({
    required String title,
    required String rootUrl,
  }) async {
    final rootUri = Uri.parse(rootUrl);
    final response = await _client.get(rootUri);
    if (response.statusCode != 200) {
      throw Exception('Could not load catalog (${response.statusCode}).');
    }

    final body = response.body.trimLeft();
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';

    if (contentType.contains('application/opds+json') || body.startsWith('{')) {
      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      final searchTemplate = _extractOpds2SearchTemplate(jsonMap, rootUri);
      if (searchTemplate == null) {
        throw Exception('This OPDS 2 catalog does not expose a search link.');
      }
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
    if (openSearchUri == null) {
      throw Exception(
        'This OPDS 1 catalog does not expose an OpenSearch description.',
      );
    }

    final openSearchResponse = await _client.get(openSearchUri);
    if (openSearchResponse.statusCode != 200) {
      throw Exception('Could not load the catalog search description.');
    }

    final openSearchDocument = XmlDocument.parse(openSearchResponse.body);
    final searchTemplate = _extractOpenSearchTemplate(openSearchDocument);
    if (searchTemplate == null) {
      throw Exception(
        'Could not find a usable search template for this catalog.',
      );
    }

    return CatalogSource(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      url: rootUri.toString(),
      kind: CatalogKind.custom,
      protocol: CatalogProtocol.opds1,
      searchTemplate: rootUri.resolve(searchTemplate).toString(),
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
            author: author.isEmpty ? 'Unknown Author' : author,
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

  List<CatalogBook> _parseOpds1Feed({
    required CatalogSource catalog,
    required Uri baseUri,
    required XmlDocument document,
  }) {
    final results = <CatalogBook>[];
    for (final entry in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'entry',
    )) {
      final acquisitions = _parseOpds1Acquisitions(entry, baseUri);
      if (acquisitions.isEmpty) continue;

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
          author: (authorName == null || authorName.isEmpty)
              ? 'Unknown Author'
              : authorName,
          description: _childText(entry, 'content'),
          coverUrl: _extractOpds1Cover(entry, baseUri)?.toString(),
          yearLabel: _childText(entry, 'published')?.split('-').first,
          externalUrl: _extractOpds1AlternateLink(entry, baseUri)?.toString(),
          catalogId: catalog.id,
          catalogTitle: catalog.title,
          acquisitions: acquisitions,
        ),
      );
    }
    return results;
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
        return baseUri.resolve(href).toString();
      }
    }
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
