import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database.dart';
import '../../../core/sync/sync_config.dart';
import '../../../core/theme/theme_cubit.dart';
import 'sync_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader('Appearance'),
          BlocBuilder<ThemeCubit, ThemeState>(
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
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          _SectionHeader('Sync'),
          BlocBuilder<SyncConfigCubit, SyncConfigState>(
            builder: (context, state) {
              final subtitle = state.isAuthenticated
                  ? 'Connected'
                  : state.config.serverUrl.isNotEmpty
                      ? 'Not logged in'
                      : 'Not configured';
              final icon = state.isAuthenticated
                  ? Icons.cloud_done
                  : Icons.cloud_outlined;
              return ListTile(
                leading: Icon(icon),
                title: const Text('Sync Server'),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
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
          const Divider(),
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Moku'),
            subtitle: const Text('Version 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source'),
            subtitle: const Text('Built with Flutter & PocketBase'),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
