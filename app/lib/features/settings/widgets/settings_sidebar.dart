import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

enum SettingsSection { appearance, battery, sync, about }

class SettingsSidebar extends StatelessWidget {
  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelect;

  const SettingsSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final sections = [
      (SettingsSection.appearance, Icons.palette_outlined, l10n.settingsSectionAppearance),
      (SettingsSection.battery, Icons.battery_std_outlined, l10n.settingsSectionBattery),
      (SettingsSection.sync, Icons.cloud_outlined, l10n.settingsSectionSync),
      (SettingsSection.about, Icons.info_outline_rounded, l10n.settingsSectionAbout),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 4),
        ...sections.map((entry) {
          final (section, icon, label) = entry;
          final isSelected = selected == section;
          return InkWell(
            onTap: () => onSelect(section),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
