import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_locale_cubit.dart';
import '../../../core/services/app_version_service.dart';
import '../../../core/sync/sync_config.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/ui/ui.dart';
import '../../../l10n/l10n.dart';
import '../screens/sync_settings_screen.dart';
import 'settings_sidebar.dart';

const _systemLocaleOption = '__system__';

class SettingsDetailPane extends StatelessWidget {
  final SettingsSection section;

  const SettingsDetailPane({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (section) {
        SettingsSection.appearance => const _AppearanceSection(),
        SettingsSection.battery    => const _BatterySection(),
        SettingsSection.sync       => const _SyncSection(),
        SettingsSection.about      => const _AboutSection(),
      },
    );
  }
}

// ── Shared layout primitives ─────────────────────────────────────────────────

/// A top-level section title.
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Text(
        title,
        style: MokuText.sectionHeading(),
      ),
    );
  }
}

/// A group label inside a section (e.g. "Language").
class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      child: Text(
        label,
        style: MokuText.sectionLabel(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A subtle container that replaces mobile-era Cards.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(MokuRadius.lg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 0,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Appearance ───────────────────────────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.settingsSectionAppearance),

            _GroupLabel(l10n.settingsLanguageTitle),
            BlocBuilder<AppLocaleCubit, AppLocaleState>(
              builder: (context, state) {
                final selected = state.localeTag ?? _systemLocaleOption;
                final options = <String>[
                  _systemLocaleOption,
                  ...AppLocalizations.supportedLocales
                      .map(AppLocaleCubit.localeToTag)
                      .whereType<String>(),
                ];
                return RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (s) {
                    if (s == null) return;
                    final c = context.read<AppLocaleCubit>();
                    s == _systemLocaleOption
                        ? c.useSystemLocale()
                        : c.setLocaleTag(s);
                  },
                  child: _SettingsGroup(
                    children: options.map((tag) {
                      return RadioListTile<String>(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(_localeLabel(context, tag)),
                        subtitle: tag == _systemLocaleOption
                            ? Text(l10n.settingsLanguageSystemSubtitle)
                            : null,
                        value: tag,
                        secondary: Icon(
                          tag == _systemLocaleOption
                              ? Icons.settings_suggest_rounded
                              : Icons.translate_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            _GroupLabel('Theme'),
            BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
                final colorScheme = Theme.of(context).colorScheme;
                return RadioGroup<ThemeMode>(
                  groupValue: state.themeMode,
                  onChanged: (m) {
                    if (m != null) {
                      context.read<ThemeCubit>().setThemeMode(m);
                    }
                  },
                  child: _SettingsGroup(
                    children: [
                      RadioListTile<ThemeMode>(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(l10n.settingsThemeSystem),
                        subtitle: Text(l10n.settingsThemeSystemSubtitle),
                        value: ThemeMode.system,
                        secondary: Icon(Icons.brightness_auto_rounded,
                            size: 18, color: colorScheme.onSurfaceVariant),
                      ),
                      RadioListTile<ThemeMode>(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(l10n.settingsThemeLight),
                        value: ThemeMode.light,
                        secondary: Icon(Icons.light_mode_rounded,
                            size: 18, color: colorScheme.onSurfaceVariant),
                      ),
                      RadioListTile<ThemeMode>(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(l10n.settingsThemeDark),
                        value: ThemeMode.dark,
                        secondary: Icon(Icons.dark_mode_rounded,
                            size: 18, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Battery ──────────────────────────────────────────────────────────────────

class _BatterySection extends StatelessWidget {
  const _BatterySection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.settingsSectionBattery),
            BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
                final colorScheme = Theme.of(context).colorScheme;
                return _SettingsGroup(
                  children: [
                    SwitchListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      secondary: Icon(
                        state.powerSaver
                            ? Icons.battery_saver_rounded
                            : Icons.battery_std_rounded,
                        size: 18,
                        color: state.powerSaver
                            ? MokuColors.successGreen
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.settingsPowerSaverTitle),
                      subtitle: Text(l10n.settingsPowerSaverSubtitle),
                      value: state.powerSaver,
                      onChanged: (v) =>
                          context.read<ThemeCubit>().setPowerSaver(v),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sync ─────────────────────────────────────────────────────────────────────

class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.settingsSectionSync),
            BlocBuilder<SyncConfigCubit, SyncConfigState>(
              builder: (context, state) {
                final colorScheme = Theme.of(context).colorScheme;
                final connected = state.isAuthenticated;
                return _SettingsGroup(
                  children: [
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        connected
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_outlined,
                        size: 18,
                        color: connected
                            ? MokuColors.successGreen
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.settingsSyncServerTitle),
                      subtitle: Text(
                        connected
                            ? l10n.settingsSyncConnected
                            : state.config.serverUrl.isNotEmpty
                                ? l10n.settingsSyncNotLoggedIn
                                : l10n.settingsSyncNotConfigured,
                        style: TextStyle(
                          color: connected
                              ? MokuColors.successGreen
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 16, color: colorScheme.onSurfaceVariant),
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
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.settingsSectionAbout),
            _SettingsGroup(
              children: [
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.auto_stories_rounded,
                      size: 18, color: colorScheme.primary),
                  title: Text(
                    l10n.appTitle,
                    style: MokuText.bookTitleSmall(),
                  ),
                  subtitle: FutureBuilder<AppVersionInfo?>(
                    future: AppVersionService.versionInfo,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.code_rounded,
                      size: 18, color: colorScheme.onSurfaceVariant),
                  title: Text(l10n.settingsOpenSourceTitle),
                  subtitle: Text(l10n.settingsOpenSourceSubtitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _localeLabel(BuildContext context, String tag) {
  final l10n = context.l10n;
  return switch (tag) {
    _systemLocaleOption => l10n.settingsLanguageSystem,
    'en'                => l10n.settingsLanguageEnglish,
    'ar'                => l10n.settingsLanguageArabic,
    _                   => tag,
  };
}
