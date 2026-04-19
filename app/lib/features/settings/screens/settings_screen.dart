import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';
import '../../../core/sync/sync_config.dart';
import '../../../core/theme/theme_cubit.dart';
import 'sync_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.literata(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          _SectionHeader('Appearance'),
          const SizedBox(height: 8),
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
                          title: const Text('System'),
                          subtitle: const Text('Follow device theme'),
                          value: ThemeMode.system,
                          secondary: Icon(Icons.brightness_auto_rounded,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Light'),
                          value: ThemeMode.light,
                          secondary: Icon(Icons.light_mode_rounded,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Dark'),
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
          const SizedBox(height: 24),
          _SectionHeader('Battery'),
          const SizedBox(height: 8),
          Card(
            child: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, state) {
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
                  title: const Text('Power Saver'),
                  subtitle: const Text(
                      'Reduce animations & scroll updates'),
                  value: state.powerSaver,
                  onChanged: (v) =>
                      context.read<ThemeCubit>().setPowerSaver(v),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Sync'),
          const SizedBox(height: 8),
          Card(
            child: BlocBuilder<SyncConfigCubit, SyncConfigState>(
              builder: (context, state) {
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
                  title: const Text('Sync Server'),
                  subtitle: Text(
                    isConnected
                        ? 'Connected'
                        : state.config.serverUrl.isNotEmpty
                            ? 'Not logged in'
                            : 'Not configured',
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
          const SizedBox(height: 24),
          _SectionHeader('About'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.auto_stories_rounded,
                      color: colorScheme.primary),
                  title: Text('Moku',
                      style: GoogleFonts.literata(
                        fontWeight: FontWeight.w600,
                      )),
                  subtitle: const Text('Version 1.0.0'),
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color:
                        colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ListTile(
                  leading: Icon(Icons.code_rounded,
                      color: colorScheme.onSurfaceVariant),
                  title: const Text('Open Source'),
                  subtitle: const Text('Flutter + PocketBase'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
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
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
