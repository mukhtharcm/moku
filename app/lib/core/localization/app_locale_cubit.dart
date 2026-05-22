import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/generated/app_localizations.dart';

class AppLocaleState extends Equatable {
  final String? localeTag;

  const AppLocaleState({this.localeTag});

  Locale? get locale => AppLocaleCubit.localeFromTag(localeTag);

  bool get followsSystem => localeTag == null;

  @override
  List<Object?> get props => [localeTag];
}

class AppLocaleCubit extends Cubit<AppLocaleState> {
  static const String preferencesKey = 'app_locale_tag';

  AppLocaleCubit() : super(const AppLocaleState());

  static final Set<String> _supportedLocaleTags = AppLocalizations
      .supportedLocales
      .map(localeToTag)
      .whereType<String>()
      .toSet();

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeTag = _supportedLocaleTag(prefs.getString(preferencesKey));
    emit(AppLocaleState(localeTag: localeTag));
  }

  Future<void> useSystemLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(preferencesKey);
    emit(const AppLocaleState());
  }

  Future<void> setLocaleTag(String localeTag) async {
    final supportedLocaleTag = _supportedLocaleTag(localeTag);
    if (supportedLocaleTag == null) {
      await useSystemLocale();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferencesKey, supportedLocaleTag);
    emit(AppLocaleState(localeTag: supportedLocaleTag));
  }

  static String? normalizeLocaleTag(String? rawTag) {
    final trimmed = rawTag?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final parts = trimmed.replaceAll('_', '-').split('-');
    if (parts.isEmpty) return null;

    final normalized = <String>[parts.first.toLowerCase()];
    for (final part in parts.skip(1)) {
      if (part.isEmpty) return null;
      if (part.length == 4) {
        normalized.add(
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        );
      } else if (part.length == 2 || part.length == 3) {
        normalized.add(part.toUpperCase());
      } else {
        normalized.add(part);
      }
    }

    return normalized.join('-');
  }

  static Locale? localeFromTag(String? rawTag) {
    final normalizedTag = normalizeLocaleTag(rawTag);
    if (normalizedTag == null) return null;

    final parts = normalizedTag.split('-');
    final languageCode = parts.first;
    String? scriptCode;
    String? countryCode;

    if (parts.length >= 2) {
      if (parts[1].length == 4) {
        scriptCode = parts[1];
        if (parts.length >= 3) {
          countryCode = parts[2];
        }
      } else {
        countryCode = parts[1];
      }
    }

    return Locale.fromSubtags(
      languageCode: languageCode,
      scriptCode: scriptCode,
      countryCode: countryCode,
    );
  }

  static String? localeToTag(Locale? locale) {
    if (locale == null || locale.languageCode.isEmpty) return null;

    final parts = <String>[locale.languageCode];
    if (locale.scriptCode case final scriptCode?) {
      if (scriptCode.isNotEmpty) parts.add(scriptCode);
    }
    if (locale.countryCode case final countryCode?) {
      if (countryCode.isNotEmpty) parts.add(countryCode);
    }

    return normalizeLocaleTag(parts.join('-'));
  }

  static String? _supportedLocaleTag(String? rawTag) {
    final normalizedTag = normalizeLocaleTag(rawTag);
    if (normalizedTag == null) return null;
    return _supportedLocaleTags.contains(normalizedTag) ? normalizedTag : null;
  }
}
