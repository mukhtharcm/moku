import '../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_locale_cubit.dart';
import '../../../core/services/app_version_service.dart';
import '../../../core/sync/sync_config.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../l10n/l10n.dart';
import 'sync_settings_screen.dart';

const _systemLocaleOption = '__system__';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          _SectionHeader(l10n.settingsSectionAppearance),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: BlocBuilder<AppLocaleCubit, AppLocaleState>(
                builder: (context, state) {
                  final selectedLocaleTag =
                      state.localeTag ?? _systemLocaleOption;
                  final localeOptions = <String>[
                    _systemLocaleOption,
                    ...AppLocalizations.supportedLocales
                        .map(AppLocaleCubit.localeToTag)
                        .whereType<String>(),
                  ];
                  return RadioGroup<String>(
                    groupValue: selectedLocaleTag,
                    onChanged: (selection) {
                      if (selection == null) return;
                      final localeCubit = context.read<AppLocaleCubit>();
                      if (selection == _systemLocaleOption) {
                        localeCubit.useSystemLocale();
                      } else {
                        localeCubit.setLocaleTag(selection);
                      }
                    },
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Icon(
                            Icons.language_rounded,
                            color: colorScheme.primary,
                          ),
                          title: Text(l10n.settingsLanguageTitle),
                        ),
                        ...localeOptions.map(
                          (localeTag) => RadioListTile<String>(
                            title: Text(_localeLabel(context, localeTag)),
                            subtitle: localeTag == _systemLocaleOption
                                ? Text(l10n.settingsLanguageSystemSubtitle)
                                : null,
                            value: localeTag,
                            secondary: Icon(
                              localeTag == _systemLocaleOption
                                  ? Icons.settings_suggest_rounded
                                  : Icons.translate_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: BlocBuilder<ThemeCubit, ThemeState>(
                builder: (context, state) {
                  return RadioGroup<ThemeMode>(
                    groupValue: state.themeMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        context.read<ThemeCubit>().setThemeMode(mode);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.settingsThemeSystem),
                          subtitle: Text(l10n.settingsThemeSystemSubtitle),
                          value: ThemeMode.system,
                          secondary: Icon(
                            Icons.brightness_auto_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.settingsThemeLight),
                          value: ThemeMode.light,
                          secondary: Icon(
                            Icons.light_mode_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.settingsThemeDark),
                          value: ThemeMode.dark,
                          secondary: Icon(
                            Icons.dark_mode_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(l10n.settingsSectionBattery),
          const SizedBox(height: 8),
          Card(
            child: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
                return SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    state.powerSaver
                        ? Icons.battery_saver_rounded
                        : Icons.battery_std_rounded,
                    color: state.powerSaver
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.settingsPowerSaverTitle),
                  subtitle: Text(l10n.settingsPowerSaverSubtitle),
                  value: state.powerSaver,
                  onChanged: (v) => context.read<ThemeCubit>().setPowerSaver(v),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(l10n.settingsSectionSync),
          const SizedBox(height: 8),
          Card(
            child: BlocBuilder<SyncConfigCubit, SyncConfigState>(
              builder: (context, state) {
                final isConnected = state.isAuthenticated;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.green.withValues(alpha: 0.1)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isConnected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_outlined,
                      color: isConnected
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  title: Text(l10n.settingsSyncServerTitle),
                  subtitle: Text(
                    isConnected
                        ? l10n.settingsSyncConnected
                        : state.config.serverUrl.isNotEmpty
                        ? l10n.settingsSyncNotLoggedIn
                        : l10n.settingsSyncNotConfigured,
                    style: TextStyle(
                      color: isConnected
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<SyncConfigCubit>(),
                        child: RepositoryProvider.value(
                          value: context.read<AppDatabase>(),
                          child: const SyncSettingsScreen(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(l10n.settingsSectionAbout),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.auto_stories_rounded,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    l10n.appTitle,
                    style: MokuText.sectionHeading(),
                  ),
                  subtitle: FutureBuilder<AppVersionInfo?>(
                    future: AppVersionService.versionInfo,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(l10n.settingsVersionLoading);
                      }

                      final versionInfo = snapshot.data;
                      return Text(
                        versionInfo == null
                            ? l10n.settingsVersionUnavailable
                            : l10n.settingsVersion(
                                version: versionInfo.buildNumber == null
                                    ? l10n.settingsVersionValue(
                                        version: versionInfo.version,
                                      )
                                    : l10n.settingsVersionValueWithBuild(
                                        version: versionInfo.version,
                                        build: versionInfo.buildNumber!,
                                      ),
                              ),
                      );
                    },
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                ListTile(
                  leading: Icon(
                    Icons.code_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(l10n.settingsOpenSourceTitle),
                  subtitle: Text(l10n.settingsOpenSourceSubtitle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

String _localeLabel(BuildContext context, String localeTag) {
  final l10n = context.l10n;
  return switch (localeTag) {
    _systemLocaleOption => l10n.settingsLanguageSystem,
    'en' => l10n.settingsLanguageEnglish,
    'ar' => l10n.settingsLanguageArabic,
    _ => localeTag,
  };
}
