import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../models/reader_content_profile.dart';
import '../../services/reader_content_resolver.dart';
import '../../services/book_service.dart';

/// Metadata extracted from a plain-text file.
class TxtMetadata {
  final String title;
  final String author;
  final int chapterCount;

  const TxtMetadata({
    required this.title,
    required this.author,
    required this.chapterCount,
  });
}

/// Parsed chapter from a text file.
class _TxtChapter {
  final String title;
  final String content;

  const _TxtChapter({required this.title, required this.content});
}

/// Parser for plain-text (.txt) book files.
///
/// Detects chapters via common patterns (Chapter X, PART X, etc.) and
/// converts text to HTML for WebView rendering.
class TxtParser {
  static final _cache = <String, List<_TxtChapter>>{};

  static final _chapterPatterns = [
    RegExp(r'^chapter\s+\d+', caseSensitive: false, multiLine: true),
    RegExp(r'^chapter\s+[IVXLCDM]+', caseSensitive: false, multiLine: true),
    RegExp(r'^CHAPTER\s+', multiLine: true),
    RegExp(r'^PART\s+\d+', caseSensitive: false, multiLine: true),
    RegExp(r'^BOOK\s+\d+', caseSensitive: false, multiLine: true),
    RegExp(r'^\*\s*\*\s*\*\s*$', multiLine: true),
    RegExp(r'^---+\s*$', multiLine: true),
    RegExp(r'^===+\s*$', multiLine: true),
  ];

  /// Extract metadata from a text file.
  static TxtMetadata extractMetadata(Uint8List bytes, String filePath) {
    final text = _decode(bytes);
    final chapters = _parseChapters(text);

    return TxtMetadata(
      title: _guessTitle(text, filePath),
      author: '',
      chapterCount: chapters.length,
    );
  }

  /// Get chapter list for reader UI.
  static Future<List<ChapterInfo>> getChapters(String filePath) async {
    final chapters = await _loadChapters(filePath);
    return chapters.asMap().entries.map((e) {
      return ChapterInfo(index: e.key, title: e.value.title);
    }).toList();
  }

  /// Get chapter content as HTML for WebView rendering.
  static Future<String> getChapterContent(
    String filePath,
    int chapterIndex,
  ) async {
    final chapters = await _loadChapters(filePath);
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return '';

    final chapter = chapters[chapterIndex];
    return _textToHtml(chapter.content);
  }

  static Future<ReaderContentProfile> getContentProfile(
    String filePath,
    int chapterIndex, {
    required String? bookLanguageTag,
    required ReaderDirectionOverride directionOverride,
  }) async {
    final chapters = await _loadChapters(filePath);
    final safeChapterIndex = chapterIndex.clamp(
      0,
      chapters.isEmpty ? 0 : chapters.length - 1,
    );
    final chapterContent = chapters.isEmpty
        ? ''
        : chapters[safeChapterIndex].content;

    return ReaderContentResolver.resolve(
      directionOverride: directionOverride,
      bookLanguageTag: bookLanguageTag,
      textSample: chapterContent,
    );
  }

  static void clearCache(String filePath) => _cache.remove(filePath);

  // ── Private helpers ──────────────────────────────────────────────────────

  static Future<List<_TxtChapter>> _loadChapters(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final text = _decode(bytes);
    final chapters = _parseChapters(text);
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

  static String _guessTitle(String text, String filePath) {
    // Use the first non-empty line as title, or filename
    final lines = text.split('\n');
    for (final line in lines.take(5)) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.length < 100) return trimmed;
    }
    return p.basenameWithoutExtension(filePath);
  }

  static List<_TxtChapter> _parseChapters(String text) {
    final lines = text.split('\n');

    // Find chapter boundaries
    final breaks = <int>[];
    final titles = <int, String>{};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      for (final pattern in _chapterPatterns) {
        if (pattern.hasMatch(line)) {
          // Skip divider-only patterns (***,---,===) for the title
          final isDivider =
              line == '***' || line.startsWith('---') || line.startsWith('===');
          breaks.add(i);
          titles[i] = isDivider ? '' : line;
          break;
        }
      }
    }

    // If fewer than 2 chapter breaks found, auto-split by ~3000 lines
    if (breaks.length < 2) {
      return _autoSplit(lines);
    }

    final chapters = <_TxtChapter>[];
    // Content before first break is "Preface"
    if (breaks.first > 0) {
      final content = lines.sublist(0, breaks.first).join('\n').trim();
      if (content.isNotEmpty) {
        chapters.add(_TxtChapter(title: '', content: content));
      }
    }

    for (int i = 0; i < breaks.length; i++) {
      final start = breaks[i];
      final end = i + 1 < breaks.length ? breaks[i + 1] : lines.length;
      final content = lines.sublist(start, end).join('\n').trim();
      if (content.isNotEmpty) {
        chapters.add(_TxtChapter(title: titles[start] ?? '', content: content));
      }
    }

    return chapters.isEmpty ? _autoSplit(lines) : chapters;
  }

  /// Auto-split large text into chunks when no chapter markers found.
  static List<_TxtChapter> _autoSplit(List<String> lines) {
    const linesPerChapter = 3000;
    final chapters = <_TxtChapter>[];

    for (int i = 0; i < lines.length; i += linesPerChapter) {
      final end = (i + linesPerChapter).clamp(0, lines.length);
      final content = lines.sublist(i, end).join('\n').trim();
      if (content.isNotEmpty) {
        chapters.add(_TxtChapter(title: '', content: content));
      }
    }

    return chapters.isEmpty
        ? [const _TxtChapter(title: '', content: '')]
        : chapters;
  }

  /// Convert plain text to styled HTML for the WebView reader.
  static String _textToHtml(String text) {
    // Escape HTML entities
    var html = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    // Convert paragraphs (double newlines → <p>)
    final paragraphs = html.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();
    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;
      // Preserve single newlines within paragraphs
      buffer.write('<p>${trimmed.replaceAll('\n', '<br>')}</p>\n');
    }

    return buffer.toString();
  }
}
