import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/models/reader_content_profile.dart';
import 'package:moku/core/services/reader_content_resolver.dart';
import 'package:moku/l10n/l10n.dart';

void main() {
  group('ReaderContentResolver', () {
    test('normalizes language tags', () {
      expect(
        ReaderContentResolver.normalizeLanguageTag('ar_EG'),
        'ar-EG',
      );
      expect(
        ReaderContentResolver.normalizeLanguageTag(' en-US '),
        'en-US',
      );
      expect(ReaderContentResolver.normalizeLanguageTag(''), isNull);
    });

    test('detects direction from language tags generically', () {
      expect(
        ReaderContentResolver.directionFromLanguageTag('ar'),
        ContentTextDirection.rtl,
      );
      expect(
        ReaderContentResolver.directionFromLanguageTag('fa-Arab'),
        ContentTextDirection.rtl,
      );
      expect(
        ReaderContentResolver.directionFromLanguageTag('en'),
        ContentTextDirection.ltr,
      );
    });

    test('extracts language and dir attributes from html', () {
      const html =
          '<html lang="ar-EG" dir="rtl"><body><p>مرحبا بالعالم</p></body></html>';

      expect(
        ReaderContentResolver.extractLanguageTagFromHtml(html),
        'ar-EG',
      );
      expect(
        ReaderContentResolver.extractDirAttributeFromHtml(html),
        'rtl',
      );
    });

    test('override wins over metadata', () {
      final profile = ReaderContentResolver.resolve(
        directionOverride: ReaderDirectionOverride.ltr,
        explicitLanguageTag: 'ar',
        explicitDir: 'rtl',
        bookLanguageTag: 'ar',
        textSample: 'مرحبا بالعالم',
      );

      expect(profile.textDirection, ContentTextDirection.ltr);
      expect(profile.pageProgressionDirection, ContentTextDirection.ltr);
      expect(profile.directionSource, ReaderDirectionSource.override);
    });

    test('falls back to heuristic when metadata is missing', () {
      final profile = ReaderContentResolver.resolve(
        directionOverride: ReaderDirectionOverride.auto,
        textSample: 'مرحبا بكم في عالم القراءة',
      );

      expect(profile.textDirection, ContentTextDirection.rtl);
      expect(profile.directionSource, ReaderDirectionSource.heuristic);
    });
  });

  test('generated localizations expose Arabic support', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('ar')));
  });
}
