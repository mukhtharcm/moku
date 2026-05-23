import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/localization/app_locale_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppLocaleCubit', () {
    test('restores a supported saved locale', () async {
      SharedPreferences.setMockInitialValues({
        AppLocaleCubit.preferencesKey: 'ar',
      });

      final cubit = AppLocaleCubit();
      await cubit.loadLocale();

      expect(cubit.state.localeTag, 'ar');
      expect(cubit.state.locale, const Locale('ar'));
    });

    test('drops an unsupported saved locale back to system', () async {
      SharedPreferences.setMockInitialValues({
        AppLocaleCubit.preferencesKey: 'fr',
      });

      final cubit = AppLocaleCubit();
      await cubit.loadLocale();

      expect(cubit.state.localeTag, isNull);
      expect(cubit.state.locale, isNull);
    });

    test('persists and clears locale selections', () async {
      final cubit = AppLocaleCubit();

      await cubit.setLocaleTag('en');

      final prefs = await SharedPreferences.getInstance();
      expect(cubit.state.localeTag, 'en');
      expect(prefs.getString(AppLocaleCubit.preferencesKey), 'en');

      await cubit.useSystemLocale();

      expect(cubit.state.localeTag, isNull);
      expect(prefs.getString(AppLocaleCubit.preferencesKey), isNull);
    });
  });

  group('AppLocaleCubit locale helpers', () {
    test('normalizes locale tags consistently', () {
      expect(AppLocaleCubit.normalizeLocaleTag(' ar_eg '), 'ar-EG');
      expect(AppLocaleCubit.normalizeLocaleTag('zh-hans'), 'zh-Hans');
      expect(AppLocaleCubit.normalizeLocaleTag(''), isNull);
    });

    test('parses locale tags into Locale objects', () {
      expect(
        AppLocaleCubit.localeFromTag('pt-BR'),
        const Locale.fromSubtags(languageCode: 'pt', countryCode: 'BR'),
      );
      expect(
        AppLocaleCubit.localeFromTag('zh-Hans'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
    });
  });
}
