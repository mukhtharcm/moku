import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/sync/sync_engine.dart';

void main() {
  group('SyncEngine.normalizeBookFormatName', () {
    test('prefers an explicit supported format', () {
      expect(
        SyncEngine.normalizeBookFormatName('pdf', filename: 'book.epub'),
        'pdf',
      );
    });

    test('falls back to the remote filename extension', () {
      expect(
        SyncEngine.normalizeBookFormatName('', filename: 'chapter.xhtml'),
        'html',
      );
      expect(
        SyncEngine.normalizeBookFormatName(null, filename: 'comic.cbz'),
        'cbz',
      );
    });

    test('defaults to epub for unknown input', () {
      expect(
        SyncEngine.normalizeBookFormatName('weird', filename: 'book.bin'),
        'epub',
      );
    });
  });
}
