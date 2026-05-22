import 'dart:convert';
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
      final headerBytes = bytes.length > 65536
          ? bytes.sublist(0, 65536)
          : bytes;

      // Extract title from /Title field
      title = _extractField(headerBytes, 'Title');
      author = _extractField(headerBytes, 'Author');
      subject = _extractField(headerBytes, 'Subject');

      // Count pages by looking for /Type /Page entries
      final pagePattern = RegExp(r'/Type\s*/Page\b');
      pageCount = pagePattern.allMatches(latin1.decode(bytes)).length;
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
    // For PDF, we don't split into chapters — the reader handles pages natively
    return [ChapterInfo(index: 0, title: '')];
  }

  /// Extract a PDF metadata field from the raw content.
  static String? _extractField(List<int> content, String field) {
    final marker = latin1.encode('/$field');
    final markerIndex = _indexOfSequence(content, marker);
    if (markerIndex == -1) return null;

    var cursor = markerIndex + marker.length;
    while (cursor < content.length && _isPdfWhitespace(content[cursor])) {
      cursor++;
    }
    if (cursor >= content.length) return null;

    if (content[cursor] == 0x28) {
      return _decodePdfString(_readLiteralString(content, cursor + 1));
    }

    if (content[cursor] == 0x3C &&
        cursor + 1 < content.length &&
        content[cursor + 1] != 0x3C) {
      return _decodePdfString(_readHexString(content, cursor + 1));
    }

    return null;
  }

  static int _indexOfSequence(List<int> content, List<int> marker) {
    if (marker.isEmpty || marker.length > content.length) return -1;

    for (var i = 0; i <= content.length - marker.length; i++) {
      var matches = true;
      for (var j = 0; j < marker.length; j++) {
        if (content[i + j] != marker[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return i;
    }

    return -1;
  }

  static bool _isPdfWhitespace(int byte) {
    return byte == 0x00 ||
        byte == 0x09 ||
        byte == 0x0A ||
        byte == 0x0C ||
        byte == 0x0D ||
        byte == 0x20;
  }

  static List<int> _readLiteralString(List<int> content, int start) {
    final bytes = <int>[];
    var depth = 1;

    for (var i = start; i < content.length; i++) {
      final byte = content[i];

      if (byte == 0x5C) {
        if (i + 1 >= content.length) break;
        final escaped = content[++i];

        if (_isOctalDigit(escaped)) {
          final octal = <int>[escaped];
          while (i + 1 < content.length &&
              octal.length < 3 &&
              _isOctalDigit(content[i + 1])) {
            octal.add(content[++i]);
          }
          bytes.add(int.parse(String.fromCharCodes(octal), radix: 8));
          continue;
        }

        switch (escaped) {
          case 0x6E:
            bytes.add(0x0A);
            break;
          case 0x72:
            bytes.add(0x0D);
            break;
          case 0x74:
            bytes.add(0x09);
            break;
          case 0x62:
            bytes.add(0x08);
            break;
          case 0x66:
            bytes.add(0x0C);
            break;
          case 0x0D:
            if (i + 1 < content.length && content[i + 1] == 0x0A) {
              i++;
            }
            break;
          case 0x0A:
            break;
          default:
            bytes.add(escaped);
        }
        continue;
      }

      if (byte == 0x28) {
        depth++;
        bytes.add(byte);
        continue;
      }

      if (byte == 0x29) {
        depth--;
        if (depth == 0) break;
        bytes.add(byte);
        continue;
      }

      bytes.add(byte);
    }

    return bytes;
  }

  static List<int> _readHexString(List<int> content, int start) {
    final hex = StringBuffer();

    for (var i = start; i < content.length; i++) {
      final byte = content[i];
      if (byte == 0x3E) break;
      if (_isPdfWhitespace(byte)) continue;
      hex.writeCharCode(byte);
    }

    var value = hex.toString();
    if (value.isEmpty) return const [];
    if (value.length.isOdd) value = '${value}0';

    final bytes = <int>[];
    for (var i = 0; i < value.length; i += 2) {
      final parsed = int.tryParse(value.substring(i, i + 2), radix: 16);
      if (parsed == null) return const [];
      bytes.add(parsed);
    }
    return bytes;
  }

  static bool _isOctalDigit(int byte) => byte >= 0x30 && byte <= 0x37;

  static String? _decodePdfString(List<int> bytes) {
    if (bytes.isEmpty) return null;

    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _sanitizeMetadata(_decodeUtf16(bytes.sublist(2), bigEndian: true));
    }

    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _sanitizeMetadata(
        _decodeUtf16(bytes.sublist(2), bigEndian: false),
      );
    }

    return _sanitizeMetadata(latin1.decode(bytes));
  }

  static String _decodeUtf16(List<int> bytes, {required bool bigEndian}) {
    final codeUnits = <int>[];
    final evenLength = bytes.length - (bytes.length % 2);

    for (var i = 0; i < evenLength; i += 2) {
      codeUnits.add(
        bigEndian
            ? (bytes[i] << 8) | bytes[i + 1]
            : (bytes[i + 1] << 8) | bytes[i],
      );
    }

    return String.fromCharCodes(codeUnits);
  }

  static String? _sanitizeMetadata(String? value) {
    if (value == null) return null;

    final cleaned = value
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'[\u0001-\u0008\u000B\u000C\u000E-\u001F]'), '')
        .trim();

    if (cleaned.isEmpty || cleaned == 'þÿ' || cleaned == 'ÿþ') {
      return null;
    }

    return cleaned;
  }
}
