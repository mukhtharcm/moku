import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_locale_cubit.dart';
import '../../../core/services/app_version_service.dart';
import '../../../core/sync/sync_config.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../l10n/l10n.dart';
import '../screens/sync_settings_screen.dart';
import 'settings_sidebar.dart';

const _systemLocaleOption = '__system__';

/// Main pane that shows the content for the currently selected settings
/// section. Passed in as [section] from the shell.
class SettingsDetailPane extends StatelessWidget {
  final SettingsSection section;

  const SettingsDetailPane({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _buildSection(context),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context) {
    return switch (section) {
      SettingsSection.appearance => const _AppearanceSection(),
      SettingsSection.battery => const _BatterySection(),
      SettingsSection.sync => const _SyncSection(),
      SettingsSection.about => const _AboutSection(),
    };
  }
}

// ── Appearance ───────────────────────────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionTitle(l10n.settingsSectionAppearance),
        const SizedBox(height: 16),

        // Language
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BlocBuilder<AppLocaleCubit, AppLocaleState>(
              builder: (context, state) {
                final selectedTag = state.localeTag ?? _systemLocaleOption;
                final options = <String>[
                  _systemLocaleOption,
                  ...AppLocalizations.supportedLocales
                      .map(AppLocaleCubit.localeToTag)
                      .whereType<String>(),
                ];
                return RadioGroup<String>(
                  groupValue: selectedTag,
                  onChanged: (s) {
                    if (s == null) return;
                    final cubit = context.read<AppLocaleCubit>();
                    s == _systemLocaleOption
                        ? cubit.useSystemLocale()
                        : cubit.setLocaleTag(s);
                  },
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Icon(Icons.language_rounded,
                            color: colorScheme.primary),
                        title: Text(l10n.settingsLanguageTitle),
                      ),
                      ...options.map(
                        (tag) => RadioListTile<String>(
                          title: Text(_localeLabel(context, tag)),
                          subtitle: tag == _systemLocaleOption
                              ? Text(l10n.settingsLanguageSystemSubtitle)
                              : null,
                          value: tag,
                          secondary: Icon(
                            tag == _systemLocaleOption
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

        const SizedBox(height: 16),

        // Theme
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
                return RadioGroup<ThemeMode>(
                  groupValue: state.themeMode,
                  onChanged: (m) {
                    if (m != null) context.read<ThemeCubit>().setThemeMode(m);
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.settingsThemeSystem),
                        subtitle: Text(l10n.settingsThemeSystemSubtitle),
                        value: ThemeMode.system,
                        secondary: Icon(Icons.brightness_auto_rounded,
                            color: colorScheme.onSurfaceVariant),
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.settingsThemeLight),
                        value: ThemeMode.light,
                        secondary: Icon(Icons.light_mode_rounded,
                            color: colorScheme.onSurfaceVariant),
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.settingsThemeDark),
                        value: ThemeMode.dark,
                        secondary: Icon(Icons.dark_mode_rounded,
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Battery ──────────────────────────────────────────────────────────────────

class _BatterySection extends StatelessWidget {
  const _BatterySection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionTitle(l10n.settingsSectionBattery),
        const SizedBox(height: 16),
        Card(
          child: BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              final colorScheme = Theme.of(context).colorScheme;
              return SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
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
                onChanged: (v) =>
                    context.read<ThemeCubit>().setPowerSaver(v),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Sync ─────────────────────────────────────────────────────────────────────

class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionTitle(l10n.settingsSectionSync),
        const SizedBox(height: 16),
        Card(
          child: BlocBuilder<SyncConfigCubit, SyncConfigState>(
            builder: (context, state) {
              final colorScheme = Theme.of(context).colorScheme;
              final isConnected = state.isAuthenticated;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
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
                trailing: Icon(Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant),
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
      ],
    );
  }
}

// ── About ─────────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionTitle(l10n.settingsSectionAbout),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.auto_stories_rounded,
                    color: colorScheme.primary),
                title: Text(l10n.appTitle,
                    style:
                        GoogleFonts.literata(fontWeight: FontWeight.w600)),
                subtitle: FutureBuilder<AppVersionInfo?>(
                  future: AppVersionService.versionInfo,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Text(l10n.settingsVersionLoading);
                    }
                    final v = snapshot.data;
                    return Text(
                      v == null
                          ? l10n.settingsVersionUnavailable
                          : l10n.settingsVersion(
                              version: v.buildNumber == null
                                  ? l10n.settingsVersionValue(
                                      version: v.version)
                                  : l10n.settingsVersionValueWithBuild(
                                      version: v.version,
                                      build: v.buildNumber!),
                            ),
                    );
                  },
                ),
              ),
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ListTile(
                leading: Icon(Icons.code_rounded,
                    color: colorScheme.onSurfaceVariant),
                title: Text(l10n.settingsOpenSourceTitle),
                subtitle: Text(l10n.settingsOpenSourceSubtitle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String _localeLabel(BuildContext context, String tag) {
  final l10n = context.l10n;
  return switch (tag) {
    _systemLocaleOption => l10n.settingsLanguageSystem,
    'en' => l10n.settingsLanguageEnglish,
    'ar' => l10n.settingsLanguageArabic,
    _ => tag,
  };
}
