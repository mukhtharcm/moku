import 'dart:io';

import 'package:path/path.dart' as p;

import '../../services/book_service.dart';

/// Metadata extracted from a PDF file.
class PdfMetadata {
  final String? title;
  final String? author;
  final String? subject;
  final int pageCount;

  const PdfMetadata({
    this.title,
    this.author,
    this.subject,
    required this.pageCount,
  });
}

/// Parser for PDF files.
///
/// PDF rendering is handled natively by pdfrx widget; this class handles
/// metadata extraction and chapter generation. Full PDF rendering is done
/// by the PdfReaderScreen using pdfrx.
class PdfParser {
  /// Extract metadata from a PDF file.
  ///
  /// We parse the PDF header for basic metadata. Full rendering is done
  /// by the pdfrx widget natively.
  static Future<PdfMetadata> extractMetadata(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Parse basic PDF metadata from the file
    String? title;
    String? author;
    String? subject;
    int pageCount = 0;

    try {
      final content = String.fromCharCodes(bytes.take(65536));

      // Extract title from /Title field
      title = _extractField(content, 'Title');
      author = _extractField(content, 'Author');
      subject = _extractField(content, 'Subject');

      // Count pages by looking for /Type /Page entries
      final pagePattern = RegExp(r'/Type\s*/Page[^s]');
      pageCount = pagePattern.allMatches(String.fromCharCodes(bytes)).length;
      if (pageCount == 0) pageCount = 1;
    } catch (_) {
      // If parsing fails, use fallback values
    }

    return PdfMetadata(
      title: title ?? p.basenameWithoutExtension(filePath),
      author: author,
      subject: subject,
      pageCount: pageCount > 0 ? pageCount : 1,
    );
  }

  /// Generate chapter list — for PDFs, each "chapter" can represent a range
  /// of pages. We use simple page groups.
  static Future<List<ChapterInfo>> getChapters(String filePath) async {
    final meta = await extractMetadata(filePath);
    // For PDF, we don't split into chapters — the reader handles pages natively
    return [
      ChapterInfo(
        index: 0,
        title: '${meta.pageCount} pages',
      ),
    ];
  }

  /// Extract a PDF metadata field from the raw content.
  static String? _extractField(String content, String field) {
    // Match patterns like /Title (Some Title) or /Title <hex>
    final pattern = RegExp(
      '/$field\\s*\\(([^)]*)\\)',
      caseSensitive: true,
    );
    final match = pattern.firstMatch(content);
    final value = match?.group(1)?.trim();
    return (value != null && value.isNotEmpty) ? value : null;
  }
}
