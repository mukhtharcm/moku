import 'dart:typed_data';

/// Fully parsed representation of an EPUB document.
class EpubDocument {
  final EpubMetadata metadata;
  final List<ManifestItem> manifest;
  final List<SpineEntry> spine;
  final List<TocEntry> tableOfContents;

  /// All resources keyed by their manifest href (relative to OPF directory).
  final Map<String, EpubResource> resources;

  /// The base directory of the OPF file within the ZIP (e.g. "OEBPS/").
  final String opfDirectory;

  EpubDocument({
    required this.metadata,
    required this.manifest,
    required this.spine,
    required this.tableOfContents,
    required this.resources,
    required this.opfDirectory,
  });

  /// Look up a resource by href with flexible matching.
  EpubResource? findResource(String href) {
    // Exact match
    if (resources.containsKey(href)) return resources[href];
    // Try with OPF directory prefix
    final withDir = '$opfDirectory$href';
    if (resources.containsKey(withDir)) return resources[withDir];
    // Try basename match
    final baseName = href.split('/').last;
    for (final entry in resources.entries) {
      if (entry.key.split('/').last == baseName) return entry.value;
    }
    // URL-decoded match
    final decoded = Uri.decodeFull(href);
    if (resources.containsKey(decoded)) return resources[decoded];
    return null;
  }
}

// ---------------------------------------------------------------------------
// Metadata
// ---------------------------------------------------------------------------

class EpubMetadata {
  final String title;
  final List<String> authors;
  final String? description;
  final String? publisher;
  final String? language;
  final String? isbn;
  final String? coverManifestId;

  const EpubMetadata({
    required this.title,
    required this.authors,
    this.description,
    this.publisher,
    this.language,
    this.isbn,
    this.coverManifestId,
  });
}

// ---------------------------------------------------------------------------
// Manifest
// ---------------------------------------------------------------------------

class ManifestItem {
  final String id;
  final String href;
  final String mediaType;
  final String? properties;

  const ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties,
  });

  bool get isHtml =>
      mediaType.contains('html') || mediaType.contains('xhtml');
  bool get isCss => mediaType.contains('css');
  bool get isImage => mediaType.startsWith('image/');
  bool get isNav => properties?.contains('nav') == true;
  bool get isCoverImage => properties?.contains('cover-image') == true;
}

// ---------------------------------------------------------------------------
// Spine
// ---------------------------------------------------------------------------

class SpineEntry {
  final String idRef;
  final bool isLinear;

  /// Resolved from manifest lookup.
  final String href;
  final String mediaType;

  const SpineEntry({
    required this.idRef,
    required this.isLinear,
    required this.href,
    required this.mediaType,
  });
}

// ---------------------------------------------------------------------------
// Table of Contents
// ---------------------------------------------------------------------------

class TocEntry {
  final String title;

  /// File path (without fragment).
  final String href;

  /// Optional fragment identifier (e.g. "_idParaDest-1").
  final String? fragment;

  /// Original href as declared in the TOC (may include #fragment).
  final String fullHref;

  final List<TocEntry> children;

  const TocEntry({
    required this.title,
    required this.href,
    this.fragment,
    required this.fullHref,
    this.children = const [],
  });

  /// Flattens the tree of TOC entries into a list (depth-first).
  List<TocEntry> flatten() {
    final result = <TocEntry>[this];
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Resources
// ---------------------------------------------------------------------------

class EpubResource {
  final String href;
  final String mediaType;
  final Uint8List data;

  EpubResource({
    required this.href,
    required this.mediaType,
    required this.data,
  });

  String? _textContent;

  /// Lazily decoded text content (for HTML, CSS, XML resources).
  String get textContent => _textContent ??= String.fromCharCodes(data);
}

// ---------------------------------------------------------------------------
// Reading Chapter — the unit exposed to the reader UI
// ---------------------------------------------------------------------------

/// A chapter as presented to the user. May correspond to a spine item
/// or a TOC entry within a spine item (with a fragment to scroll to).
class ReadingChapter {
  final int index;
  final String title;

  /// The XHTML resource href to load.
  final String contentHref;

  /// Optional fragment to scroll to after loading content.
  final String? fragment;

  const ReadingChapter({
    required this.index,
    required this.title,
    required this.contentHref,
    this.fragment,
  });
}
