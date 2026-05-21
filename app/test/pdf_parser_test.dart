import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/formats/pdf/pdf_parser.dart';

void main() {
  group('PdfParser.extractMetadata', () {
    test('decodes UTF-16BE metadata strings', () async {
      final file = await _writePdfFile('utf16_title.pdf', [
        ...latin1.encode('%PDF-1.4\n1 0 obj\n<< /Title ('),
        ..._utf16Be('test_book_pdf'),
        ...latin1.encode(') /Author ('),
        ..._utf16Be('Jane Doe'),
        ...latin1.encode(
          ') >>\nendobj\n2 0 obj\n<< /Type /Page >>\nendobj\n%%EOF',
        ),
      ]);

      final metadata = await PdfParser.extractMetadata(file.path);

      expect(metadata.title, 'test_book_pdf');
      expect(metadata.author, 'Jane Doe');
      expect(metadata.pageCount, 1);
    });

    test('falls back to the filename when metadata is unusable', () async {
      final file = await _writePdfFile('fallback_name.pdf', [
        ...latin1.encode('%PDF-1.4\n1 0 obj\n<< /Title ('),
        0xFE,
        0xFF,
        ...latin1.encode(
          ') >>\nendobj\n2 0 obj\n<< /Type /Page >>\nendobj\n%%EOF',
        ),
      ]);

      final metadata = await PdfParser.extractMetadata(file.path);

      expect(metadata.title, 'fallback_name');
    });
  });
}

Future<File> _writePdfFile(String fileName, List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp(
    'moku_pdf_parser_test_',
  );
  addTearDown(() => directory.delete(recursive: true));

  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

List<int> _utf16Be(String value) {
  final bytes = <int>[0xFE, 0xFF];
  for (final codeUnit in value.codeUnits) {
    bytes
      ..add((codeUnit >> 8) & 0xFF)
      ..add(codeUnit & 0xFF);
  }
  return bytes;
}
