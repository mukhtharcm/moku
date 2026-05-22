import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            _StreakItem(
              icon: Icons.local_fire_department_rounded,
              iconColor: currentStreak > 0 ? Colors.orange : Colors.grey,
              value: '$currentStreak',
              label: l10n.statsCurrentStreak,
              theme: theme,
            ),
            const SizedBox(width: 16),
            VerticalDivider(width: 16, thickness: 1, color: theme.dividerColor),
            const SizedBox(width: 16),
            _StreakItem(
              icon: Icons.emoji_events_rounded,
              iconColor: longestStreak > 0 ? Colors.amber : Colors.grey,
              value: '$longestStreak',
              label: l10n.statsLongestStreak,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final ThemeData theme;

  const _StreakItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 36, color: iconColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
