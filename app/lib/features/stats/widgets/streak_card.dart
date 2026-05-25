import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ui/ui.dart';
import '../../../l10n/l10n.dart';
import 'stats_semantics.dart';

/// Hero streak card — uses big Literata numbers rather than the default
/// material card + icon + small-number layout.
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
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    return StatsSemanticSection(
      child: Row(
        children: [
          Expanded(
            child: _BigStreakStat(
              value: '$currentStreak',
              label: l10n.statsCurrentStreak,
              icon: Icons.local_fire_department_rounded,
              iconColor: currentStreak > 0
                  ? const Color(0xFFE6621E)
                  : colorScheme.outlineVariant,
              isDesktop: isDesktop,
            ),
          ),
          Container(
            width: 1,
            height: isDesktop ? 64 : 48,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _BigStreakStat(
              value: '$longestStreak',
              label: l10n.statsLongestStreak,
              icon: Icons.emoji_events_rounded,
              iconColor: longestStreak > 0
                  ? const Color(0xFFD4A017)
                  : colorScheme.outlineVariant,
              isDesktop: isDesktop,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStreakStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isDesktop;

  const _BigStreakStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final numSize = isDesktop ? MokuTypeSize.h1 : MokuTypeSize.h2;

    return StatsSemanticNode(
      label: label,
      value: value,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MokuSpacing.s5,
          vertical: isDesktop ? MokuSpacing.s5 : MokuSpacing.s4,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: isDesktop ? 32 : 26, color: iconColor),
            const SizedBox(width: MokuSpacing.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.literata(
                    fontSize: numSize,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: MokuText.caption(
                    color: colorScheme.onSurfaceVariant,
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
