import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../models/reader_content_profile.dart';
import '../../services/reader_content_resolver.dart';
import '../../services/book_service.dart';

/// Metadata extracted from an HTML file.
class HtmlMetadata {
  final String title;
  final String author;
  final int chapterCount;
  final String? languageTag;
  final ContentTextDirection? textDirection;

  const HtmlMetadata({
    required this.title,
    required this.author,
    required this.chapterCount,
    this.languageTag,
    this.textDirection,
  });
}

class _HtmlChapter {
  final String title;
  final String content;

  const _HtmlChapter({required this.title, required this.content});
}

/// Parser for HTML book files (.html, .htm, .xhtml).
///
/// Extracts title from <title> tag, splits by <h1>/<h2> headings into chapters.
/// Content is served as-is to the WebView reader (already HTML).
class HtmlParser {
  static final _cache = <String, List<_HtmlChapter>>{};

  /// Extract metadata from an HTML file.
  static HtmlMetadata extractMetadata(Uint8List bytes, String filePath) {
    final html = _decode(bytes);
    final chapters = _parseChapters(html, filePath);

    return HtmlMetadata(
      title: _extractTitle(html, filePath),
      author: _extractAuthor(html),
      chapterCount: chapters.length,
      languageTag: ReaderContentResolver.extractLanguageTagFromHtml(html),
      textDirection: ReaderContentResolver.directionFromDirAttribute(
        ReaderContentResolver.extractDirAttributeFromHtml(html),
      ),
    );
  }

  /// Get chapter list for reader UI.
  static Future<List<ChapterInfo>> getChapters(String filePath) async {
    final chapters = await _loadChapters(filePath);
    return chapters.asMap().entries.map((e) {
      return ChapterInfo(index: e.key, title: e.value.title);
    }).toList();
  }

  /// Get chapter content (body HTML) for WebView rendering.
  static Future<String> getChapterContent(
    String filePath,
    int chapterIndex,
  ) async {
    final chapters = await _loadChapters(filePath);
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return '';
    return chapters[chapterIndex].content;
  }

  static Future<ReaderContentProfile> getContentProfile(
    String filePath,
    int chapterIndex, {
    required String? bookLanguageTag,
    required ReaderDirectionOverride directionOverride,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final html = _decode(bytes);
    final chapters = _parseChapters(html, filePath);
    final safeChapterIndex = chapterIndex.clamp(
      0,
      chapters.isEmpty ? 0 : chapters.length - 1,
    );
    final chapterContent = chapters.isEmpty
        ? html
        : chapters[safeChapterIndex].content;

    return ReaderContentResolver.resolve(
      directionOverride: directionOverride,
      explicitLanguageTag: ReaderContentResolver.extractLanguageTagFromHtml(
        html,
      ),
      explicitDir: ReaderContentResolver.extractDirAttributeFromHtml(html),
      bookLanguageTag: bookLanguageTag,
      textSample: chapterContent,
    );
  }

  static void clearCache(String filePath) => _cache.remove(filePath);

  // ── Private helpers ──────────────────────────────────────────────────────

  static Future<List<_HtmlChapter>> _loadChapters(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final html = _decode(bytes);
    final chapters = _parseChapters(html, filePath);
    _cache[filePath] = chapters;
    return chapters;
  }

  static String _decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static String _extractTitle(String html, String filePath) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match != null) {
      final title = match.group(1)?.trim() ?? '';
      if (title.isNotEmpty) return _stripTags(title);
    }
    return p.basenameWithoutExtension(filePath);
  }

  static String _extractAuthor(String html) {
    // Try meta tag: <meta name="author" content="...">
    final match = RegExp(
      r'<meta\s+name\s*=\s*"author"\s+content\s*=\s*"([^"]*)"',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1)?.trim() ?? '';
  }

  /// Extract body content from full HTML document.
  static String _extractBody(String html) {
    final bodyMatch = RegExp(
      r'<body[^>]*>(.*)</body>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return bodyMatch?.group(1)?.trim() ?? html;
  }

  /// Split HTML into chapters by <h1> or <h2> headings.
  static List<_HtmlChapter> _parseChapters(String html, String filePath) {
    final body = _extractBody(html);

    // Find all h1/h2 tags as chapter boundaries
    final headingPattern = RegExp(
      r'<(h[12])[^>]*>(.*?)</\1>',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = headingPattern.allMatches(body).toList();

    if (matches.length < 2) {
      // Single chapter: the whole document
      return [
        _HtmlChapter(title: _extractTitle(html, filePath), content: body),
      ];
    }

    final chapters = <_HtmlChapter>[];

    // Content before first heading
    if (matches.first.start > 0) {
      final preContent = body.substring(0, matches.first.start).trim();
      if (preContent.isNotEmpty) {
        chapters.add(_HtmlChapter(title: '', content: preContent));
      }
    }

    for (int i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = i + 1 < matches.length ? matches[i + 1].start : body.length;
      final content = body.substring(start, end).trim();
      final title = _stripTags(matches[i].group(2) ?? '');

      if (content.isNotEmpty) {
        chapters.add(_HtmlChapter(title: title, content: content));
      }
    }

    return chapters.isEmpty
        ? [_HtmlChapter(title: _extractTitle(html, filePath), content: body)]
        : chapters;
  }

  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
