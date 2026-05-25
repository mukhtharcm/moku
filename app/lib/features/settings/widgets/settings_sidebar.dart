import 'package:flutter/material.dart';
import '../../../core/ui/ui.dart';
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
    final l10n = context.l10n;

    final sections = [
      (SettingsSection.appearance, Icons.palette_outlined,
          l10n.settingsSectionAppearance),
      (SettingsSection.battery, Icons.battery_std_outlined,
          l10n.settingsSectionBattery),
      (SettingsSection.sync, Icons.cloud_outlined, l10n.settingsSectionSync),
      (SettingsSection.about, Icons.info_outline_rounded,
          l10n.settingsSectionAbout),
    ];

    return Column(
      children: [
        MokuPanelHeader(label: l10n.settingsTitle),
        const SizedBox(height: MokuSpacing.s1),
        ...sections.map((entry) {
          final (section, icon, label) = entry;
          return MokuPanelItem(
            leading: Icon(icon, size: 16,
                color: selected == section
                    ? context.colors.accent
                    : context.colors.textSecondary),
            title: label,
            selected: selected == section,
            onTap: () => onSelect(section),
          );
        }),
      ],
    );
  }
}
