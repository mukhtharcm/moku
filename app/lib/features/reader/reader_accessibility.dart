import 'package:html/parser.dart' as html_parser;

const int readerAccessibilityPreviewMaxLength = 240;

String readerAccessibilityTextPreview(
  String rawContent, {
  int maxLength = readerAccessibilityPreviewMaxLength,
}) {
  final trimmed = rawContent.trim();
  if (trimmed.isEmpty || maxLength <= 0) {
    return '';
  }

  final fragment = html_parser.parseFragment(trimmed);
  for (final element in fragment.querySelectorAll('script, style, noscript')) {
    element.remove();
  }

  final normalizedText = (fragment.text ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalizedText.isEmpty) {
    return '';
  }

  if (normalizedText.length <= maxLength) {
    return normalizedText;
  }

  final cutoff = maxLength - 3;
  if (cutoff <= 0) {
    return normalizedText.substring(0, maxLength);
  }

  var truncated = normalizedText.substring(0, cutoff).trimRight();
  final lastSpace = truncated.lastIndexOf(' ');
  if (lastSpace >= cutoff ~/ 2) {
    truncated = truncated.substring(0, lastSpace).trimRight();
  }

  return '$truncated...';
}
