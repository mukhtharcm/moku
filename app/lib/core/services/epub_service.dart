import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// Cached representation of a parsed EPUB, keyed by file path.
class _CachedEpub {
  final EpubBook book;
  final List<SpineItem> spineItems;
  final Map<String, String> imageDataUris; // href -> data:image/...;base64,...

  _CachedEpub({
    required this.book,
    required this.spineItems,
    required this.imageDataUris,
  });
}

class EpubService {
  static const _uuid = Uuid();

  // Cache the parsed epub to avoid re-parsing on every chapter navigation
  final Map<String, _CachedEpub> _cache = {};

  /// Parse an EPUB file and extract metadata + cover
  Future<Book> parseEpub(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'moku_books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final bookId = _uuid.v4();

    // Copy epub to app directory
    final destPath = p.join(booksDir.path, '$bookId.epub');
    await file.copy(destPath);

    // Extract cover image
    String? coverPath;
    try {
      coverPath = await _extractCover(epubBook, booksDir.path, bookId);
    } catch (_) {
      // Cover extraction is optional
    }

    // Count spine items (actual reading sections)
    final spineItems = _buildSpineItems(epubBook);

    final now = DateTime.now();
    return Book(
      id: bookId,
      title: epubBook.Title ?? 'Unknown Title',
      author: epubBook.AuthorList?.join(', ') ?? 'Unknown Author',
      description: _extractDescription(epubBook),
      coverPath: coverPath,
      filePath: destPath,
      isbn: _extractIsbn(epubBook),
      language: epubBook.Schema?.Package?.Metadata?.Languages?.firstOrNull,
      publisher:
          epubBook.Schema?.Package?.Metadata?.Publishers?.firstOrNull,
      totalChapters: spineItems.length,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Open an EPUB for reading — caches the parsed content
  Future<_CachedEpub> _openBook(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final spineItems = _buildSpineItems(epubBook);
    final imageDataUris = _buildImageDataUris(epubBook);

    final cached = _CachedEpub(
      book: epubBook,
      spineItems: spineItems,
      imageDataUris: imageDataUris,
    );
    _cache[filePath] = cached;
    return cached;
  }

  /// Evict a book from cache (call when closing the reader)
  void closeBook(String filePath) {
    _cache.remove(filePath);
  }

  /// Get reading-order sections (spine items) with resolved titles
  Future<List<SpineItem>> getSpineItems(String filePath) async {
    final cached = await _openBook(filePath);
    return cached.spineItems;
  }

  /// Get HTML content for a spine item, with images embedded as data URIs
  Future<String> getSpineContent(String filePath, int spineIndex) async {
    final cached = await _openBook(filePath);

    if (spineIndex < 0 || spineIndex >= cached.spineItems.length) {
      return '<p>Section not found</p>';
    }

    final item = cached.spineItems[spineIndex];
    final htmlFiles = cached.book.Content?.Html;
    if (htmlFiles == null) return '<p>No content</p>';

    // Look up the content by href (try exact match, then basename)
    String? htmlContent;
    for (final entry in htmlFiles.entries) {
      final entryName = entry.key;
      if (entryName == item.href ||
          p.basename(entryName) == p.basename(item.href) ||
          entryName.endsWith(item.href) ||
          item.href.endsWith(entryName)) {
        htmlContent = entry.value.Content;
        break;
      }
    }

    if (htmlContent == null) return '<p>Content not available</p>';

    // Embed images as data URIs so they render in loadHtmlString
    htmlContent = _embedImages(htmlContent, cached.imageDataUris, item.href);

    // Embed CSS inline
    htmlContent = _embedCss(htmlContent, cached.book);

    return htmlContent;
  }

  // --- Legacy API wrappers for backward compatibility ---

  Future<List<EpubChapterInfo>> getChapters(String filePath) async {
    final items = await getSpineItems(filePath);
    return items
        .map((s) => EpubChapterInfo(
              index: s.index,
              title: s.title,
              fileName: s.href,
            ))
        .toList();
  }

  Future<String> getChapterContent(String filePath, int chapterIndex) async {
    return getSpineContent(filePath, chapterIndex);
  }

  // --- Spine building ---

  /// Build reading-order list from the EPUB spine + manifest + TOC
  List<SpineItem> _buildSpineItems(EpubBook epubBook) {
    final spine = epubBook.Schema?.Package?.Spine;
    final manifest = epubBook.Schema?.Package?.Manifest;

    if (spine?.Items == null || manifest?.Items == null) {
      // Fallback: use TOC chapters if spine is unavailable
      return _buildFromChapters(epubBook);
    }

    // Build id→manifest lookup
    final manifestById = <String, EpubManifestItem>{};
    for (final item in manifest!.Items!) {
      if (item.Id != null) manifestById[item.Id!] = item;
    }

    // Build href→TOC title lookup from chapters
    final tocTitles = _buildTocTitleMap(epubBook);

    final items = <SpineItem>[];
    for (int i = 0; i < spine!.Items!.length; i++) {
      final spineRef = spine.Items![i];
      final manifestItem = manifestById[spineRef.IdRef];
      if (manifestItem == null) continue;

      final href = manifestItem.Href ?? '';
      // Only include HTML/XHTML content (skip images, CSS referenced in spine)
      final mediaType = manifestItem.MediaType ?? '';
      if (!mediaType.contains('html') && !mediaType.contains('xml')) continue;

      // Resolve title: try TOC first, then fallback
      final title = _resolveTocTitle(href, tocTitles) ??
          'Section ${items.length + 1}';

      items.add(SpineItem(
        index: items.length,
        idRef: spineRef.IdRef ?? '',
        href: href,
        title: title,
        isLinear: spineRef.IsLinear ?? true,
      ));
    }

    return items.isEmpty ? _buildFromChapters(epubBook) : items;
  }

  /// Fallback: build from TOC chapters when spine is not available
  List<SpineItem> _buildFromChapters(EpubBook epubBook) {
    final chapters = epubBook.Chapters ?? [];
    return List.generate(chapters.length, (i) {
      final ch = chapters[i];
      return SpineItem(
        index: i,
        idRef: '',
        href: ch.ContentFileName ?? '',
        title: ch.Title ?? 'Chapter ${i + 1}',
        isLinear: true,
      );
    });
  }

  /// Build href→title map from TOC (chapters + sub-chapters)
  Map<String, String> _buildTocTitleMap(EpubBook epubBook) {
    final map = <String, String>{};
    final chapters = epubBook.Chapters ?? [];
    for (final ch in chapters) {
      if (ch.ContentFileName != null && ch.Title != null) {
        // Store by basename and full path for flexible matching
        map[ch.ContentFileName!] = ch.Title!;
        map[p.basename(ch.ContentFileName!)] = ch.Title!;
        // Strip fragment (e.g., "chapter1.xhtml#sec1" → "chapter1.xhtml")
        final noFragment = ch.ContentFileName!.split('#').first;
        map[noFragment] = ch.Title!;
        map[p.basename(noFragment)] = ch.Title!;
      }
      for (final sub in ch.SubChapters ?? []) {
        if (sub.ContentFileName != null && sub.Title != null) {
          map[sub.ContentFileName!] = sub.Title!;
          map[p.basename(sub.ContentFileName!)] = sub.Title!;
          final noFragment = sub.ContentFileName!.split('#').first;
          map[noFragment] = sub.Title!;
          map[p.basename(noFragment)] = sub.Title!;
        }
      }
    }
    return map;
  }

  /// Find a TOC title for a given href
  String? _resolveTocTitle(String href, Map<String, String> tocTitles) {
    // Try exact match
    if (tocTitles.containsKey(href)) return tocTitles[href];
    // Try basename
    final baseName = p.basename(href);
    if (tocTitles.containsKey(baseName)) return tocTitles[baseName];
    // Try without fragment
    final noFragment = href.split('#').first;
    if (tocTitles.containsKey(noFragment)) return tocTitles[noFragment];
    if (tocTitles.containsKey(p.basename(noFragment))) {
      return tocTitles[p.basename(noFragment)];
    }
    return null;
  }

  // --- Image embedding ---

  /// Pre-compute data URIs for all images in the EPUB
  Map<String, String> _buildImageDataUris(EpubBook epubBook) {
    final dataUris = <String, String>{};
    final images = epubBook.Content?.Images;
    if (images == null) return dataUris;

    for (final entry in images.entries) {
      final imageFile = entry.value;
      if (imageFile.Content == null) continue;

      final mimeType = imageFile.ContentMimeType ?? 'image/png';
      final base64Data = base64Encode(imageFile.Content!);
      final dataUri = 'data:$mimeType;base64,$base64Data';

      // Store by multiple key variants for flexible matching
      dataUris[entry.key] = dataUri;
      dataUris[p.basename(entry.key)] = dataUri;
    }

    return dataUris;
  }

  /// Replace image src attributes with data URIs
  String _embedImages(
      String html, Map<String, String> imageDataUris, String currentHref) {
    if (imageDataUris.isEmpty) return html;

    // Resolve relative paths relative to the current content file's directory
    final contentDir = p.dirname(currentHref);

    return html.replaceAllMapped(
      RegExp(r'''(src\s*=\s*["'])([^"']+)(["'])''', caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        final src = match.group(2)!;
        final suffix = match.group(3)!;

        // Skip already-embedded data URIs
        if (src.startsWith('data:')) return match.group(0)!;

        // Try resolving the image path
        final resolvedPath = _resolveHref(src, contentDir);
        final dataUri = imageDataUris[src] ??
            imageDataUris[p.basename(src)] ??
            imageDataUris[resolvedPath] ??
            imageDataUris[p.basename(resolvedPath)];

        if (dataUri != null) {
          return '$prefix$dataUri$suffix';
        }
        return match.group(0)!;
      },
    );
  }

  /// Resolve a relative href against a base directory
  String _resolveHref(String href, String baseDir) {
    if (href.startsWith('/') || href.startsWith('http')) return href;
    // Normalize: "../images/foo.png" from "OEBPS/text/" → "OEBPS/images/foo.png"
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

  /// Embed CSS from the EPUB inline into the HTML
  String _embedCss(String html, EpubBook epubBook) {
    final cssFiles = epubBook.Content?.Css;
    if (cssFiles == null || cssFiles.isEmpty) return html;

    // Collect all CSS content
    final cssBuffer = StringBuffer();
    for (final entry in cssFiles.entries) {
      if (entry.value.Content != null) {
        cssBuffer.writeln(entry.value.Content);
      }
    }

    if (cssBuffer.isEmpty) return html;

    // Inject CSS before </head> or at the start
    final cssTag = '<style type="text/css">${cssBuffer.toString()}</style>';
    if (html.contains('</head>')) {
      return html.replaceFirst('</head>', '$cssTag</head>');
    }
    return '$cssTag$html';
  }

  // --- Cover and metadata extraction ---

  Future<String?> _extractCover(
    EpubBook epubBook,
    String directory,
    String bookId,
  ) async {
    final coverImage = epubBook.CoverImage;
    if (coverImage == null) return null;

    final coversDir = Directory(p.join(directory, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final coverPath = p.join(coversDir.path, '$bookId.jpg');
    final encoded = img.encodeJpg(coverImage, quality: 85);
    await File(coverPath).writeAsBytes(encoded);

    return coverPath;
  }

  String? _extractDescription(EpubBook epubBook) {
    return epubBook.Schema?.Package?.Metadata?.Description;
  }

  String? _extractIsbn(EpubBook epubBook) {
    final identifiers =
        epubBook.Schema?.Package?.Metadata?.Identifiers;
    if (identifiers != null) {
      for (final id in identifiers) {
        if (id.Scheme?.toLowerCase() == 'isbn' ||
            id.Id?.toLowerCase() == 'isbn') {
          return id.Identifier;
        }
      }
    }
    return null;
  }
}

/// A section in the EPUB reading order (from the spine)
class SpineItem {
  final int index;
  final String idRef;
  final String href;
  final String title;
  final bool isLinear;

  const SpineItem({
    required this.index,
    required this.idRef,
    required this.href,
    required this.title,
    required this.isLinear,
  });
}

/// Backward-compatible chapter info (wraps SpineItem data)
class EpubChapterInfo {
  final int index;
  final String title;
  final String fileName;

  const EpubChapterInfo({
    required this.index,
    required this.title,
    required this.fileName,
  });
}
