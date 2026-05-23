import 'package:flutter_test/flutter_test.dart';
import 'package:moku/features/reader/reader_accessibility.dart';

void main() {
  group('readerAccessibilityTextPreview', () {
    test('extracts readable text from html content', () {
      const html = '''
<article>
  <h1>Chapter 1</h1>
  <p>Hello <strong>reader</strong>.</p>
  <p>Welcome to <em>Moku</em>.</p>
</article>
''';

      expect(
        readerAccessibilityTextPreview(html),
        'Chapter 1 Hello reader. Welcome to Moku.',
      );
    });

    test('drops non-readable tags and decodes entities', () {
      const html = '''
<html>
  <head>
    <style>body { color: red; }</style>
    <script>window.hidden = true;</script>
  </head>
  <body>
    <p>Fish &amp; Chips</p>
    <noscript>Ignore me</noscript>
  </body>
</html>
''';

      expect(readerAccessibilityTextPreview(html), 'Fish & Chips');
    });

    test('preserves arabic text and truncates at a word boundary', () {
      const html =
          '<p>مرحبا بكم في قارئ موكو حيث يمكنكم قراءة الكتب بسهولة ووضوح مع دعم الاتجاه الصحيح للنص.</p>';

      expect(
        readerAccessibilityTextPreview(html, maxLength: 48),
        'مرحبا بكم في قارئ موكو حيث يمكنكم قراءة...',
      );
    });
  });
}
