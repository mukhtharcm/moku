import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'epub_document.dart';

/// Parses EPUB files (both EPUB 2 and EPUB 3) from raw ZIP bytes.
class EpubParser {
  /// Parse an EPUB from raw bytes.
  static EpubDocument parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Locate the OPF file via META-INF/container.xml
    final opfPath = _findOpfPath(archive);
    final opfDir = _dirname(opfPath);

    // 2. Read and parse the OPF
    final opfXml = _readTextFile(archive, opfPath);
    final opfDoc = XmlDocument.parse(opfXml);

    // 3. Parse manifest
    final manifest = _parseManifest(opfDoc);
    final manifestById = {for (final m in manifest) m.id: m};

    // 4. Parse metadata
    final metadata = _parseMetadata(opfDoc, manifestById);

    // 5. Parse spine (resolving against manifest)
    final spine = _parseSpine(opfDoc, manifestById);

    // 6. Parse TOC (try EPUB 3 nav.xhtml first, fall back to NCX)
    final toc = _parseToc(archive, manifest, opfDir, opfDoc);

    // 7. Load all resources from the ZIP
    final resources = _loadResources(archive);

    return EpubDocument(
      metadata: metadata,
      manifest: manifest,
      spine: spine,
      tableOfContents: toc,
      resources: resources,
      opfDirectory: opfDir,
    );
  }

  // -----------------------------------------------------------------------
  // Container
  // -----------------------------------------------------------------------

  static String _findOpfPath(Archive archive) {
    final containerFile = archive.files.firstWhere(
      (f) => f.name == 'META-INF/container.xml',
      orElse: () => throw FormatException('No META-INF/container.xml found'),
    );
    final xml = String.fromCharCodes(containerFile.content as List<int>);
    final doc = XmlDocument.parse(xml);
    final rootfile = doc.findAllElements('rootfile').firstOrNull;
    final path = rootfile?.getAttribute('full-path');
    if (path == null || path.isEmpty) {
      throw const FormatException('No rootfile full-path in container.xml');
    }
    return path;
  }

  // -----------------------------------------------------------------------
  // Metadata
  // -----------------------------------------------------------------------

  static EpubMetadata _parseMetadata(
    XmlDocument opfDoc,
    Map<String, ManifestItem> manifestById,
  ) {
    String title = 'Unknown Title';
    final authors = <String>[];
    String? description;
    String? publisher;
    String? language;
    String? isbn;
    String? coverManifestId;

    // Find the <metadata> element (may be namespaced)
    final metadataEl = opfDoc.findAllElements('metadata').firstOrNull;
    if (metadataEl != null) {
      // Title
      final titleEl =
          metadataEl.findAllElements('dc:title').firstOrNull ??
          metadataEl.findAllElements('title').firstOrNull;
      if (titleEl != null && titleEl.innerText.isNotEmpty) {
        title = titleEl.innerText.trim();
      }

      // Authors (dc:creator)
      for (final el in [
        ...metadataEl.findAllElements('dc:creator'),
        ...metadataEl.findAllElements('creator'),
      ]) {
        final name = el.innerText.trim();
        if (name.isNotEmpty && !authors.contains(name)) authors.add(name);
      }

      // Description
      final descEl =
          metadataEl.findAllElements('dc:description').firstOrNull ??
          metadataEl.findAllElements('description').firstOrNull;
      description = descEl?.innerText.trim();
      if (description?.isEmpty == true) description = null;

      // Publisher
      final pubEl =
          metadataEl.findAllElements('dc:publisher').firstOrNull ??
          metadataEl.findAllElements('publisher').firstOrNull;
      publisher = pubEl?.innerText.trim();
      if (publisher?.isEmpty == true) publisher = null;

      // Language
      final langEl =
          metadataEl.findAllElements('dc:language').firstOrNull ??
          metadataEl.findAllElements('language').firstOrNull;
      language = langEl?.innerText.trim();
      if (language?.isEmpty == true) language = null;

      // ISBN from dc:identifier
      for (final el in [
        ...metadataEl.findAllElements('dc:identifier'),
        ...metadataEl.findAllElements('identifier'),
      ]) {
        final scheme =
            el.getAttribute('opf:scheme')?.toLowerCase() ??
            el.getAttribute('scheme')?.toLowerCase() ??
            '';
        final idAttr = el.getAttribute('id')?.toLowerCase() ?? '';
        if (scheme == 'isbn' || idAttr.contains('isbn')) {
          isbn = el.innerText.trim();
          break;
        }
      }

      // Cover image: <meta name="cover" content="manifest-id"> (EPUB 2)
      for (final meta in metadataEl.findAllElements('meta')) {
        if (meta.getAttribute('name')?.toLowerCase() == 'cover') {
          coverManifestId = meta.getAttribute('content');
          break;
        }
      }
    }

    // EPUB 3 cover: manifest item with properties="cover-image"
    if (coverManifestId == null) {
      for (final item in manifestById.values) {
        if (item.isCoverImage) {
          coverManifestId = item.id;
          break;
        }
      }
    }

    return EpubMetadata(
      title: title,
      authors: authors.isEmpty ? ['Unknown Author'] : authors,
      description: description,
      publisher: publisher,
      language: language,
      isbn: isbn,
      coverManifestId: coverManifestId,
    );
  }

  // -----------------------------------------------------------------------
  // Manifest
  // -----------------------------------------------------------------------

  static List<ManifestItem> _parseManifest(XmlDocument opfDoc) {
    final items = <ManifestItem>[];
    for (final el in opfDoc.findAllElements('item')) {
      final id = el.getAttribute('id');
      final href = el.getAttribute('href');
      final mediaType = el.getAttribute('media-type');
      if (id == null || href == null || mediaType == null) continue;

      items.add(ManifestItem(
        id: id,
        href: Uri.decodeFull(href),
        mediaType: mediaType,
        properties: el.getAttribute('properties'),
      ));
    }
    return items;
  }

  // -----------------------------------------------------------------------
  // Spine
  // -----------------------------------------------------------------------

  static List<SpineEntry> _parseSpine(
    XmlDocument opfDoc,
    Map<String, ManifestItem> manifestById,
  ) {
    final spineEl = opfDoc.findAllElements('spine').firstOrNull;
    if (spineEl == null) return [];

    final entries = <SpineEntry>[];
    for (final ref in spineEl.findElements('itemref')) {
      final idRef = ref.getAttribute('idref');
      if (idRef == null) continue;

      final manifestItem = manifestById[idRef];
      if (manifestItem == null) continue;

      // Only include HTML/XHTML content
      if (!manifestItem.isHtml) continue;

      final linearAttr = ref.getAttribute('linear');
      // Per spec: linear defaults to "yes" if absent
      final isLinear =
          linearAttr == null || linearAttr.toLowerCase() != 'no';

      entries.add(SpineEntry(
        idRef: idRef,
        isLinear: isLinear,
        href: manifestItem.href,
        mediaType: manifestItem.mediaType,
      ));
    }
    return entries;
  }

  // -----------------------------------------------------------------------
  // TOC — tries EPUB 3 nav.xhtml first, then EPUB 2 NCX
  // -----------------------------------------------------------------------

  static List<TocEntry> _parseToc(
    Archive archive,
    List<ManifestItem> manifest,
    String opfDir,
    XmlDocument opfDoc,
  ) {
    // EPUB 3: look for manifest item with properties="nav"
    final navItem = manifest.where((m) => m.isNav).firstOrNull;
    if (navItem != null) {
      final navPath = _resolveHref(navItem.href, opfDir);
      final navFile = _findFile(archive, navPath);
      if (navFile != null) {
        final navXml = String.fromCharCodes(navFile.content as List<int>);
        final entries = _parseNavXhtml(navXml);
        if (entries.isNotEmpty) return entries;
      }
    }

    // EPUB 2: find .ncx file (referenced by spine toc attribute or by media-type)
    final spineEl = opfDoc.findAllElements('spine').firstOrNull;
    final tocId = spineEl?.getAttribute('toc');
    ManifestItem? ncxItem;
    if (tocId != null) {
      ncxItem = manifest.where((m) => m.id == tocId).firstOrNull;
    }
    ncxItem ??= manifest
        .where((m) => m.mediaType == 'application/x-dtbncx+xml')
        .firstOrNull;

    if (ncxItem != null) {
      final ncxPath = _resolveHref(ncxItem.href, opfDir);
      final ncxFile = _findFile(archive, ncxPath);
      if (ncxFile != null) {
        final ncxXml = String.fromCharCodes(ncxFile.content as List<int>);
        return _parseNcx(ncxXml);
      }
    }

    return [];
  }

  /// Parse an EPUB 3 navigation document (nav.xhtml).
  static List<TocEntry> _parseNavXhtml(String xhtml) {
    final doc = XmlDocument.parse(xhtml);
    // Find the <nav epub:type="toc"> element
    for (final nav in doc.findAllElements('nav')) {
      final epubType =
          nav.getAttribute('epub:type') ?? nav.getAttribute('type') ?? '';
      if (epubType.contains('toc')) {
        final ol = nav.findElements('ol').firstOrNull;
        if (ol != null) return _parseNavOl(ol);
      }
    }
    return [];
  }

  static List<TocEntry> _parseNavOl(XmlElement ol) {
    final entries = <TocEntry>[];
    for (final li in ol.findElements('li')) {
      final a = li.findElements('a').firstOrNull;
      if (a == null) continue;

      final fullHref = a.getAttribute('href') ?? '';
      final parts = fullHref.split('#');
      final href = Uri.decodeFull(parts[0]);
      final fragment = parts.length > 1 ? parts[1] : null;
      final title = a.innerText.trim();

      // Check for nested <ol>
      final childOl = li.findElements('ol').firstOrNull;
      final children = childOl != null ? _parseNavOl(childOl) : <TocEntry>[];

      if (title.isNotEmpty) {
        entries.add(TocEntry(
          title: title,
          href: href,
          fragment: fragment,
          fullHref: fullHref,
          children: children,
        ));
      }
    }
    return entries;
  }

  /// Parse an EPUB 2 NCX TOC.
  static List<TocEntry> _parseNcx(String ncxXml) {
    final doc = XmlDocument.parse(ncxXml);
    final navMap = doc.findAllElements('navMap').firstOrNull;
    if (navMap == null) return [];

    return _parseNavPoints(navMap);
  }

  static List<TocEntry> _parseNavPoints(XmlElement parent) {
    final entries = <TocEntry>[];
    for (final np in parent.findElements('navPoint')) {
      final label = np
          .findElements('navLabel')
          .firstOrNull
          ?.findElements('text')
          .firstOrNull
          ?.innerText
          .trim();
      final src =
          np.findElements('content').firstOrNull?.getAttribute('src') ?? '';

      if (label == null || label.isEmpty) continue;

      final decodedSrc = Uri.decodeFull(src);
      final parts = decodedSrc.split('#');
      final href = parts[0];
      final fragment = parts.length > 1 ? parts[1] : null;

      final children = _parseNavPoints(np);

      entries.add(TocEntry(
        title: label,
        href: href,
        fragment: fragment,
        fullHref: decodedSrc,
        children: children,
      ));
    }
    return entries;
  }

  // -----------------------------------------------------------------------
  // Resources
  // -----------------------------------------------------------------------

  static Map<String, EpubResource> _loadResources(Archive archive) {
    final resources = <String, EpubResource>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      // Skip META-INF and mimetype
      if (file.name.startsWith('META-INF/') || file.name == 'mimetype') {
        continue;
      }

      final mediaType = _guessMediaType(file.name);
      resources[file.name] = EpubResource(
        href: file.name,
        mediaType: mediaType,
        data: Uint8List.fromList(file.content as List<int>),
      );
    }
    return resources;
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  static String _readTextFile(Archive archive, String path) {
    final file = archive.files.firstWhere(
      (f) => f.name == path,
      orElse: () => throw FormatException('File not found in EPUB: $path'),
    );
    return String.fromCharCodes(file.content as List<int>);
  }

  static ArchiveFile? _findFile(Archive archive, String path) {
    for (final f in archive.files) {
      if (f.name == path) return f;
    }
    // Try case-insensitive and with/without leading slash
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    for (final f in archive.files) {
      if (f.name.toLowerCase() == normalized.toLowerCase()) return f;
    }
    return null;
  }

  static String _dirname(String path) {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '';
  }

  static String _resolveHref(String href, String baseDir) {
    if (href.startsWith('/') || href.startsWith('http')) return href;
    return '$baseDir$href';
  }

  static String _guessMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.xhtml') || lower.endsWith('.html') || lower.endsWith('.htm')) {
      return 'application/xhtml+xml';
    }
    if (lower.endsWith('.css')) return 'text/css';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.ttf')) return 'font/ttf';
    if (lower.endsWith('.otf')) return 'font/otf';
    if (lower.endsWith('.woff')) return 'font/woff';
    if (lower.endsWith('.woff2')) return 'font/woff2';
    if (lower.endsWith('.ncx')) return 'application/x-dtbncx+xml';
    if (lower.endsWith('.opf')) return 'application/oebps-package+xml';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.js')) return 'application/javascript';
    return 'application/octet-stream';
  }
}
