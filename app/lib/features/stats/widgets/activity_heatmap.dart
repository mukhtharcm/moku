import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class ActivityHeatmap extends StatelessWidget {
  final Map<DateTime, int> dailyMinutes;

  const ActivityHeatmap({super.key, required this.dailyMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    const totalDays = 371; // 53 weeks × 7
    final startDate = todayMidnight.subtract(
      const Duration(days: totalDays - 1),
    );

    final days = List.generate(
      totalDays,
      (i) => startDate.add(Duration(days: i)),
    );

    final maxMinutes = dailyMinutes.values.fold(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.statsReadingActivity,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 12.0 * 7 + 2.0 * 6, // 7 rows × cell + gaps
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final mins = dailyMinutes[day] ?? 0;
              final intensity = maxMinutes > 0 ? mins / maxMinutes : 0.0;
              return Tooltip(
                message: _tooltip(context, day, mins),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cellColor(context, intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              context.l10n.statsHeatmapLess,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
            for (final intensity in [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: _cellColor(context, intensity),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            Text(
              context.l10n.statsHeatmapMore,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Color _cellColor(BuildContext context, double intensity) {
    if (intensity == 0) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
    return Colors.orange.withValues(alpha: 0.2 + intensity * 0.8);
  }

  String _tooltip(BuildContext context, DateTime day, int minutes) {
    final label = MaterialLocalizations.of(context).formatShortDate(day);
    if (minutes == 0) {
      return context.l10n.statsHeatmapNoReading(date: label);
    }

    return context.l10n.statsHeatmapMinutes(date: label, minutes: minutes);
  }
}
