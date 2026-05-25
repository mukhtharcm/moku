import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

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

// ── Shared layout primitives ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MokuSpacing.s5),
      child: Text(
        title,
        style: GoogleFonts.literata(
          fontSize: MokuTypeSize.h3,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// macOS-style group container: warm fill, no border, slight radius.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: MokuRadius.lgAll,
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
                indent: MokuSpacing.s4,
                endIndent: 0,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );
  }
}

/// A single tappable settings row — no radio button, just a checkmark on
/// the right when selected. Much cleaner on desktop.
class _OptionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.title,
    this.subtitle,
    this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MokuSpacing.s4,
          vertical: MokuSpacing.s3,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: MokuSpacing.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: MokuText.body()),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: MokuText.caption(
                            color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded,
                  size: 16, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// A toggle row (for on/off settings).
class _ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MokuSpacing.s4,
        vertical: MokuSpacing.s2,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: MokuSpacing.s3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: MokuText.body()),
                if (subtitle != null)
                  Text(subtitle!,
                      style: MokuText.caption(
                          color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MokuSpacing.s2),
      child: MokuSectionLabel(label),
    );
  }
}

// ── Appearance ────────────────────────────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MokuSpacing.s8, MokuSpacing.s6,
          MokuSpacing.s8, MokuSpacing.s8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.settingsSectionAppearance),

            // Language
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
                return _SettingsGroup(
                  children: options.map((tag) {
                    return _OptionRow(
                      title: _localeLabel(context, tag),
                      subtitle: tag == _systemLocaleOption
                          ? l10n.settingsLanguageSystemSubtitle
                          : null,
                      leading: Icon(
                        tag == _systemLocaleOption
                            ? Icons.settings_suggest_rounded
                            : Icons.translate_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      selected: selected == tag,
                      onTap: () {
                        final c = context.read<AppLocaleCubit>();
                        tag == _systemLocaleOption
                            ? c.useSystemLocale()
                            : c.setLocaleTag(tag);
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: MokuSpacing.s5),

            // Theme
            _GroupLabel('Theme'),
            BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
                return _SettingsGroup(
                  children: [
                    _OptionRow(
                      title: l10n.settingsThemeSystem,
                      subtitle: l10n.settingsThemeSystemSubtitle,
                      leading: Icon(Icons.brightness_auto_rounded,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      selected: state.themeMode == ThemeMode.system,
                      onTap: () => context
                          .read<ThemeCubit>()
                          .setThemeMode(ThemeMode.system),
                    ),
                    _OptionRow(
                      title: l10n.settingsThemeLight,
                      leading: Icon(Icons.light_mode_rounded,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      selected: state.themeMode == ThemeMode.light,
                      onTap: () => context
                          .read<ThemeCubit>()
                          .setThemeMode(ThemeMode.light),
                    ),
                    _OptionRow(
                      title: l10n.settingsThemeDark,
                      leading: Icon(Icons.dark_mode_rounded,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      selected: state.themeMode == ThemeMode.dark,
                      onTap: () => context
                          .read<ThemeCubit>()
                          .setThemeMode(ThemeMode.dark),
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

// ── Battery ───────────────────────────────────────────────────────────────────

class _BatterySection extends StatelessWidget {
  const _BatterySection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MokuSpacing.s8, MokuSpacing.s6,
          MokuSpacing.s8, MokuSpacing.s8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.settingsSectionBattery),
            BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
                return _SettingsGroup(
                  children: [
                    _ToggleRow(
                      title: l10n.settingsPowerSaverTitle,
                      subtitle: l10n.settingsPowerSaverSubtitle,
                      leading: Icon(
                        state.powerSaver
                            ? Icons.battery_saver_rounded
                            : Icons.battery_std_rounded,
                        size: 16,
                        color: state.powerSaver
                            ? MokuColors.successGreen
                            : colorScheme.onSurfaceVariant,
                      ),
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

// ── Sync ──────────────────────────────────────────────────────────────────────

class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MokuSpacing.s8, MokuSpacing.s6,
          MokuSpacing.s8, MokuSpacing.s8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                    InkWell(
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MokuSpacing.s4,
                          vertical: MokuSpacing.s3,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              connected
                                  ? Icons.cloud_done_rounded
                                  : Icons.cloud_outlined,
                              size: 16,
                              color: connected
                                  ? MokuColors.successGreen
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: MokuSpacing.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.settingsSyncServerTitle,
                                      style: MokuText.body()),
                                  Text(
                                    connected
                                        ? l10n.settingsSyncConnected
                                        : state.config.serverUrl.isNotEmpty
                                            ? l10n.settingsSyncNotLoggedIn
                                            : l10n.settingsSyncNotConfigured,
                                    style: MokuText.caption(
                                      color: connected
                                          ? MokuColors.successGreen
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant),
                          ],
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
      padding: const EdgeInsets.fromLTRB(
          MokuSpacing.s8, MokuSpacing.s6,
          MokuSpacing.s8, MokuSpacing.s8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.settingsSectionAbout),
            _SettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MokuSpacing.s4,
                    vertical: MokuSpacing.s3,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_stories_rounded,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: MokuSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.appTitle,
                                style: GoogleFonts.literata(
                                    fontWeight: FontWeight.w600,
                                    fontSize: MokuTypeSize.bodyM)),
                            FutureBuilder<AppVersionInfo?>(
                              future: AppVersionService.versionInfo,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text(l10n.settingsVersionLoading,
                                      style: MokuText.caption());
                                }
                                final v = snapshot.data;
                                return Text(
                                  v == null
                                      ? l10n.settingsVersionUnavailable
                                      : l10n.settingsVersion(
                                          version: v.buildNumber == null
                                              ? l10n.settingsVersionValue(
                                                  version: v.version)
                                              : l10n
                                                  .settingsVersionValueWithBuild(
                                                  version: v.version,
                                                  build: v.buildNumber!)),
                                  style: MokuText.caption(
                                      color: colorScheme.onSurfaceVariant),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MokuSpacing.s4,
                    vertical: MokuSpacing.s3,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.code_rounded,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: MokuSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.settingsOpenSourceTitle,
                                style: MokuText.body()),
                            Text(l10n.settingsOpenSourceSubtitle,
                                style: MokuText.caption(
                                    color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _localeLabel(BuildContext context, String tag) {
  final l10n = context.l10n;
  return switch (tag) {
    _systemLocaleOption => l10n.settingsLanguageSystem,
    'en'                => l10n.settingsLanguageEnglish,
    'ar'                => l10n.settingsLanguageArabic,
    _                   => tag,
  };
}
