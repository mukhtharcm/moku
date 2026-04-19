import 'dart:convert';

import 'epub_document.dart';

/// Serves EPUB content for the reader.
///
/// Handles smart chapter building, image/CSS embedding, and fragment
/// scrolling for both single-file and multi-file EPUBs.
class EpubContentServer {
  final EpubDocument document;

  /// Pre-computed image data URIs: resource href → "data:mime;base64,..."
  late final Map<String, String> _imageDataUris;

  /// Pre-computed CSS content: all CSS concatenated.
  late final String _cssContent;

  /// The reading chapters (smart blend of spine + TOC).
  late final List<ReadingChapter> chapters;

  EpubContentServer(this.document) {
    _imageDataUris = _buildImageDataUris();
    _cssContent = _buildCssContent();
    chapters = _buildChapters();
  }

  // -----------------------------------------------------------------------
  // Chapter building — the core algorithm
  // -----------------------------------------------------------------------

  List<ReadingChapter> _buildChapters() {
    final spine = document.spine;
    final toc = document.tableOfContents;

    if (spine.isEmpty) return [];

    // Flatten TOC tree into a list
    final flatToc = <TocEntry>[];
    for (final entry in toc) {
      flatToc.addAll(entry.flatten());
    }

    // Group TOC entries by the file they reference (without fragment)
    final tocByFile = <String, List<TocEntry>>{};
    for (final entry in flatToc) {
      final normalized = _normalizeHref(entry.href);
      tocByFile.putIfAbsent(normalized, () => []).add(entry);
    }

    // Count how many spine items have multiple TOC entries
    // (signals single-file EPUB)
    int spineItemsWithMultipleToc = 0;
    for (final s in spine) {
      final normalized = _normalizeHref(s.href);
      final tocEntries = tocByFile[normalized] ?? [];
      if (tocEntries.length > 1) spineItemsWithMultipleToc++;
    }

    // If TOC provides more granularity than spine → use TOC entries as
    // chapters (this handles single-file EPUBs where all TOC entries
    // point to one file with fragments)
    if (flatToc.length > spine.length && spineItemsWithMultipleToc > 0) {
      return _buildFromToc(flatToc, spine);
    }

    // Otherwise use spine items, assigning TOC titles where available
    return _buildFromSpine(spine, tocByFile);
  }

  /// Build chapters from TOC entries (single-file or fragment-heavy EPUBs).
  List<ReadingChapter> _buildFromToc(
    List<TocEntry> flatToc,
    List<SpineEntry> spine,
  ) {
    // Build set of TOC-referenced files for gap detection
    final tocFiles = <String>{};
    for (final entry in flatToc) {
      tocFiles.add(_normalizeHref(entry.href));
    }

    final chapters = <ReadingChapter>[];

    // First, add any spine items before the first TOC entry
    // (e.g. cover page, title page)
    for (final s in spine) {
      final normalized = _normalizeHref(s.href);
      if (tocFiles.contains(normalized)) break;
      chapters.add(ReadingChapter(
        index: chapters.length,
        title: 'Section ${chapters.length + 1}',
        contentHref: s.href,
      ));
    }

    // Add each TOC entry as a chapter
    for (final entry in flatToc) {
      chapters.add(ReadingChapter(
        index: chapters.length,
        title: entry.title,
        contentHref: entry.href,
        fragment: entry.fragment,
      ));
    }

    return chapters;
  }

  /// Build chapters from spine items (multi-file EPUBs).
  List<ReadingChapter> _buildFromSpine(
    List<SpineEntry> spine,
    Map<String, List<TocEntry>> tocByFile,
  ) {
    final chapters = <ReadingChapter>[];

    for (final s in spine) {
      final normalized = _normalizeHref(s.href);
      final tocEntries = tocByFile[normalized];

      if (tocEntries != null && tocEntries.length == 1) {
        // Exact 1:1 mapping — use TOC title
        chapters.add(ReadingChapter(
          index: chapters.length,
          title: tocEntries.first.title,
          contentHref: s.href,
          fragment: tocEntries.first.fragment,
        ));
      } else if (tocEntries != null && tocEntries.length > 1) {
        // Multiple TOC entries for this spine item — expand
        for (final entry in tocEntries) {
          chapters.add(ReadingChapter(
            index: chapters.length,
            title: entry.title,
            contentHref: s.href,
            fragment: entry.fragment,
          ));
        }
      } else {
        // No TOC entry — use generic title
        chapters.add(ReadingChapter(
          index: chapters.length,
          title: 'Section ${chapters.length + 1}',
          contentHref: s.href,
        ));
      }
    }

    return chapters;
  }

  // -----------------------------------------------------------------------
  // Content rendering
  // -----------------------------------------------------------------------

  /// Get the rendered HTML for a chapter, with images and CSS embedded.
  String getChapterContent(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      return '<html><body><p>Chapter not found</p></body></html>';
    }

    final chapter = chapters[chapterIndex];
    var html = _getHtmlContent(chapter.contentHref);
    if (html == null) {
      return '<html><body><p>Content not available for: '
          '${chapter.contentHref}</p></body></html>';
    }

    // Embed images as data URIs
    html = _embedImages(html, chapter.contentHref);

    // Embed CSS
    html = _embedCss(html);

    // If there's a fragment, inject JS to scroll to it
    if (chapter.fragment != null) {
      html = _injectFragmentScroll(html, chapter.fragment!);
    }

    return html;
  }

  /// Get the cover image bytes and media type, if available.
  ({String mediaType, List<int> data})? getCoverImage() {
    final coverId = document.metadata.coverManifestId;
    if (coverId == null) return null;

    // Find the manifest item
    final manifestItem = document.manifest
        .where((m) => m.id == coverId)
        .firstOrNull;
    if (manifestItem == null) return null;

    // Find the resource
    final resource = document.findResource(manifestItem.href);
    if (resource == null) return null;

    return (mediaType: resource.mediaType, data: resource.data);
  }

  // -----------------------------------------------------------------------
  // HTML content lookup
  // -----------------------------------------------------------------------

  String? _getHtmlContent(String href) {
    // Try finding the resource with flexible matching
    final resource = document.findResource(href);
    if (resource != null) return resource.textContent;

    // Try with OPF directory prefix
    final withDir = '${document.opfDirectory}$href';
    final dirResource = document.resources[withDir];
    if (dirResource != null) return dirResource.textContent;

    // Try matching by basename across all resources
    final baseName = href.split('/').last;
    for (final entry in document.resources.entries) {
      if (entry.key.split('/').last == baseName &&
          entry.value.mediaType.contains('html')) {
        return entry.value.textContent;
      }
    }

    return null;
  }

  // -----------------------------------------------------------------------
  // Image embedding
  // -----------------------------------------------------------------------

  Map<String, String> _buildImageDataUris() {
    final dataUris = <String, String>{};
    for (final entry in document.resources.entries) {
      if (!entry.value.mediaType.startsWith('image/')) continue;

      final base64Data = base64Encode(entry.value.data);
      final dataUri = 'data:${entry.value.mediaType};base64,$base64Data';

      // Store by multiple key variants for flexible matching
      dataUris[entry.key] = dataUri;
      dataUris[entry.key.split('/').last] = dataUri;
      // Without OPF directory prefix
      if (entry.key.startsWith(document.opfDirectory)) {
        dataUris[entry.key.substring(document.opfDirectory.length)] = dataUri;
      }
    }
    return dataUris;
  }

  String _embedImages(String html, String currentHref) {
    if (_imageDataUris.isEmpty) return html;

    final contentDir = _parentDir(currentHref);

    return html.replaceAllMapped(
      RegExp(r'''(src\s*=\s*["'])([^"']+)(["'])''', caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        final src = match.group(2)!;
        final suffix = match.group(3)!;

        if (src.startsWith('data:')) return match.group(0)!;

        final dataUri = _resolveImageUri(src, contentDir);
        if (dataUri != null) return '$prefix$dataUri$suffix';

        return match.group(0)!;
      },
    );
  }

  String? _resolveImageUri(String src, String contentDir) {
    // Direct lookup
    if (_imageDataUris.containsKey(src)) return _imageDataUris[src];

    // By basename
    final baseName = src.split('/').last;
    if (_imageDataUris.containsKey(baseName)) return _imageDataUris[baseName];

    // Resolve relative path
    final resolved = _resolveRelativeHref(src, contentDir);
    if (_imageDataUris.containsKey(resolved)) return _imageDataUris[resolved];
    if (_imageDataUris.containsKey(resolved.split('/').last)) {
      return _imageDataUris[resolved.split('/').last];
    }

    // With OPF directory
    final withOpf = '${document.opfDirectory}$src';
    if (_imageDataUris.containsKey(withOpf)) return _imageDataUris[withOpf];

    return null;
  }

  // -----------------------------------------------------------------------
  // CSS embedding
  // -----------------------------------------------------------------------

  String _buildCssContent() {
    final buffer = StringBuffer();
    for (final entry in document.resources.entries) {
      if (entry.value.mediaType.contains('css')) {
        buffer.writeln(entry.value.textContent);
      }
    }
    return buffer.toString();
  }

  String _embedCss(String html) {
    if (_cssContent.isEmpty) return html;

    final cssTag = '<style type="text/css">$_cssContent</style>';
    if (html.contains('</head>')) {
      return html.replaceFirst('</head>', '$cssTag</head>');
    }
    // No <head> — prepend
    return '$cssTag$html';
  }

  // -----------------------------------------------------------------------
  // Fragment scrolling
  // -----------------------------------------------------------------------

  String _injectFragmentScroll(String html, String fragment) {
    final script = '''
<script type="text/javascript">
  window.addEventListener('load', function() {
    var target = document.getElementById('$fragment');
    if (target) {
      target.scrollIntoView({behavior: 'instant', block: 'start'});
    }
  });
</script>
''';
    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$script</body>');
    }
    return '$html$script';
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Normalize an href for comparison (lowercase basename, strip fragment).
  String _normalizeHref(String href) {
    final noFragment = href.split('#').first;
    return noFragment.split('/').last.toLowerCase();
  }

  /// Get the parent directory of a path.
  String _parentDir(String path) {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(0, lastSlash) : '';
  }

  /// Resolve a relative href (handles ../ segments).
  String _resolveRelativeHref(String href, String baseDir) {
    if (href.startsWith('/') || href.startsWith('http')) return href;
    if (baseDir.isEmpty) return href;

    final parts = [...baseDir.split('/'), ...href.split('/')];
    final resolved = <String>[];
    for (final part in parts) {
      if (part == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else if (part != '.' && part.isNotEmpty) {
        resolved.add(part);
      }
    }
    return resolved.join('/');
  }
}
