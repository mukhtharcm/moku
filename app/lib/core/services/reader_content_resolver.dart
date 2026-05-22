import '../models/reader_content_profile.dart';

class ReaderContentResolver {
  static const Set<String> _rtlLanguageCodes = {
    'ar',
    'dv',
    'fa',
    'he',
    'ku',
    'ps',
    'sd',
    'ug',
    'ur',
    'yi',
  };

  static const Set<String> _rtlScriptCodes = {
    'adlm',
    'arab',
    'hebr',
    'mand',
    'mero',
    'nkoo',
    'rohg',
    'samr',
    'syrc',
    'thaa',
  };

  static String? normalizeLanguageTag(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final normalized = trimmed.replaceAll('_', '-');
    if (!RegExp(r'^[A-Za-z]{2,8}([\-][A-Za-z0-9]{1,8})*$').hasMatch(
      normalized,
    )) {
      return null;
    }

    return normalized;
  }

  static ContentTextDirection? directionFromLanguageTag(String? rawTag) {
    final tag = normalizeLanguageTag(rawTag);
    if (tag == null) return null;

    final parts = tag.split('-');
    final primary = parts.first.toLowerCase();
    final loweredParts = parts.map((part) => part.toLowerCase()).toSet();

    if (_rtlLanguageCodes.contains(primary)) {
      return ContentTextDirection.rtl;
    }

    if (loweredParts.any(_rtlScriptCodes.contains)) {
      return ContentTextDirection.rtl;
    }

    return ContentTextDirection.ltr;
  }

  static ContentTextDirection? directionFromDirAttribute(String? dir) {
    return switch (dir?.trim().toLowerCase()) {
      'rtl' => ContentTextDirection.rtl,
      'ltr' => ContentTextDirection.ltr,
      _ => null,
    };
  }

  static String? extractLanguageTagFromHtml(String html) {
    final htmlMatch = RegExp(
      r"""<html\b[^>]*\blang\s*=\s*["']([^"']+)["']""",
      caseSensitive: false,
    ).firstMatch(html);
    if (htmlMatch != null) {
      return normalizeLanguageTag(htmlMatch.group(1));
    }

    final bodyMatch = RegExp(
      r"""<body\b[^>]*\blang\s*=\s*["']([^"']+)["']""",
      caseSensitive: false,
    ).firstMatch(html);
    return normalizeLanguageTag(bodyMatch?.group(1));
  }

  static String? extractDirAttributeFromHtml(String html) {
    final htmlMatch = RegExp(
      r"""<html\b[^>]*\bdir\s*=\s*["']([^"']+)["']""",
      caseSensitive: false,
    ).firstMatch(html);
    if (htmlMatch != null) {
      return htmlMatch.group(1)?.trim();
    }

    final bodyMatch = RegExp(
      r"""<body\b[^>]*\bdir\s*=\s*["']([^"']+)["']""",
      caseSensitive: false,
    ).firstMatch(html);
    return bodyMatch?.group(1)?.trim();
  }

  static ContentTextDirection estimateDirectionFromText(String? rawText) {
    if (rawText == null || rawText.trim().isEmpty) {
      return ContentTextDirection.ltr;
    }

    var rtlCount = 0;
    var ltrCount = 0;

    for (final rune in rawText.runes) {
      if (_isRtlRune(rune)) {
        rtlCount++;
      } else if (_isLtrRune(rune)) {
        ltrCount++;
      }
    }

    if (rtlCount == 0 && ltrCount == 0) {
      return ContentTextDirection.ltr;
    }

    return rtlCount > ltrCount
        ? ContentTextDirection.rtl
        : ContentTextDirection.ltr;
  }

  static ReaderContentProfile resolve({
    required ReaderDirectionOverride directionOverride,
    String? explicitLanguageTag,
    String? explicitDir,
    String? bookLanguageTag,
    String? textSample,
    ContentTextDirection? pageProgressionDirection,
  }) {
    if (directionOverride != ReaderDirectionOverride.auto) {
      final overriddenDirection = directionOverride == ReaderDirectionOverride.rtl
          ? ContentTextDirection.rtl
          : ContentTextDirection.ltr;
      return ReaderContentProfile(
        languageTag: normalizeLanguageTag(explicitLanguageTag ?? bookLanguageTag),
        textDirection: overriddenDirection,
        pageProgressionDirection:
            pageProgressionDirection ?? overriddenDirection,
        directionSource: ReaderDirectionSource.override,
      );
    }

    final normalizedLanguage = normalizeLanguageTag(explicitLanguageTag);
    final dirFromAttribute = directionFromDirAttribute(explicitDir);
    if (dirFromAttribute != null) {
      return ReaderContentProfile(
        languageTag: normalizedLanguage ?? normalizeLanguageTag(bookLanguageTag),
        textDirection: dirFromAttribute,
        pageProgressionDirection: pageProgressionDirection ?? dirFromAttribute,
        directionSource: ReaderDirectionSource.contentMetadata,
      );
    }

    final dirFromExplicitLanguage = directionFromLanguageTag(normalizedLanguage);
    if (dirFromExplicitLanguage != null) {
      return ReaderContentProfile(
        languageTag: normalizedLanguage,
        textDirection: dirFromExplicitLanguage,
        pageProgressionDirection:
            pageProgressionDirection ?? dirFromExplicitLanguage,
        directionSource: ReaderDirectionSource.formatMetadata,
      );
    }

    final normalizedBookLanguage = normalizeLanguageTag(bookLanguageTag);
    final dirFromBookLanguage = directionFromLanguageTag(normalizedBookLanguage);
    if (dirFromBookLanguage != null) {
      return ReaderContentProfile(
        languageTag: normalizedBookLanguage,
        textDirection: dirFromBookLanguage,
        pageProgressionDirection:
            pageProgressionDirection ?? dirFromBookLanguage,
        directionSource: ReaderDirectionSource.bookMetadata,
      );
    }

    final heuristicDirection = estimateDirectionFromText(textSample);
    return ReaderContentProfile(
      languageTag: normalizedLanguage ?? normalizedBookLanguage,
      textDirection: heuristicDirection,
      pageProgressionDirection: pageProgressionDirection ?? heuristicDirection,
      directionSource: textSample == null || textSample.trim().isEmpty
          ? ReaderDirectionSource.fallback
          : ReaderDirectionSource.heuristic,
    );
  }

  static bool _isRtlRune(int rune) {
    return (rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF) ||
        (rune >= 0x1EE00 && rune <= 0x1EEFF);
  }

  static bool _isLtrRune(int rune) {
    return (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x02AF);
  }
}
