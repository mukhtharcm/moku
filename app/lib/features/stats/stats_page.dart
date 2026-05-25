import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/database/database.dart';
import '../../core/ui/ui.dart';
import '../../l10n/l10n.dart';
import 'cubit/stats_cubit.dart';
import 'cubit/stats_state.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/stats_semantics.dart';
import 'widgets/streak_card.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          StatsCubit(database: context.read<AppDatabase>())..load(),
      child: const _StatsView(),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(title: Text(l10n.statsTitle), centerTitle: false),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state.status == StatsStatus.loading ||
              state.status == StatsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == StatsStatus.error) {
            return Center(child: Text(l10n.statsErrorFallback));
          }

          if (isDesktop) {
            return _DesktopDashboard(state: state);
          }

          // Mobile / tablet: single-column list
          return RefreshIndicator(
            onRefresh: () => context.read<StatsCubit>().load(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: MokuSpacing.contentWide),
                child: ListView(
                  padding: const EdgeInsets.all(MokuSpacing.s4),
                  children: [
                    StreakCard(
                      currentStreak: state.currentStreak,
                      longestStreak: state.longestStreak,
                    ),
                    const SizedBox(height: MokuSpacing.s4),
                    _SummaryRow(state: state),
                    const SizedBox(height: MokuSpacing.s4),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(MokuSpacing.s4),
                        child: ActivityHeatmap(
                            dailyMinutes: state.dailyMinutes),
                      ),
                    ),
                    if (state.recentSessions.isNotEmpty) ...[
                      const SizedBox(height: MokuSpacing.s4),
                      _RecentSessions(sessions: state.recentSessions),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Desktop dashboard ─────────────────────────────────────────────────────────

class _DesktopDashboard extends StatelessWidget {
  final StatsState state;
  const _DesktopDashboard({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return RefreshIndicator(
      onRefresh: () => context.read<StatsCubit>().load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          MokuSpacing.s8, MokuSpacing.s5,
          MokuSpacing.s8, MokuSpacing.s8,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MokuSpacing.contentWide),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(l10n.statsTitle,
                    style: GoogleFonts.literata(
                      fontSize: MokuTypeSize.h2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    )),
                const SizedBox(height: MokuSpacing.s6),

                // ── Row 1: Streak (left, large) + 3 summary stats (right) ──
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Streak block
                      Expanded(
                        flex: 2,
                        child: _SurfaceBox(
                          child: StreakCard(
                            currentStreak: state.currentStreak,
                            longestStreak: state.longestStreak,
                          ),
                        ),
                      ),
                      const SizedBox(width: MokuSpacing.s3),
                      // Summary stats column
                      Expanded(
                        flex: 3,
                        child: _SummaryRow(
                            state: state, vertical: true),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MokuSpacing.s4),

                // ── Row 2: Activity heatmap ────────────────────────────────
                _SurfaceBox(
                  padding: const EdgeInsets.all(MokuSpacing.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reading Activity',
                          style: MokuText.bodySmall(
                            color: colors.textSecondary,
                            weight: FontWeight.w600,
                          )),
                      const SizedBox(height: MokuSpacing.s3),
                      ActivityHeatmap(dailyMinutes: state.dailyMinutes),
                    ],
                  ),
                ),

                // ── Row 3: Recent sessions ─────────────────────────────────
                if (state.recentSessions.isNotEmpty) ...[
                  const SizedBox(height: MokuSpacing.s4),
                  _RecentSessions(sessions: state.recentSessions),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Borderless surface box — replaces Material Cards.
class _SurfaceBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SurfaceBox({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: MokuRadius.lgAll,
      ),
      child: child,
    );
  }
}

// ── Summary row / column ──────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final StatsState state;
  final bool vertical; // true = desktop column of 3 tall tiles
  const _SummaryRow({required this.state, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final h = state.totalMinutes ~/ 60;
    final m = state.totalMinutes % 60;
    final l10n = context.l10n;
    final timeLabel = h > 0
        ? l10n.statsDurationHoursMinutes(hours: h, minutes: m)
        : l10n.statsDurationMinutes(minutes: m);

    final tiles = [
      _StatTile(
        icon: Icons.schedule_rounded,
        iconColor: const Color(0xFF3B82F6),
        value: timeLabel,
        label: l10n.statsTotalTime,
        stretch: vertical,
      ),
      _StatTile(
        icon: Icons.menu_book_rounded,
        iconColor: const Color(0xFF22C55E),
        value: '${state.booksReadThisYear}',
        label: l10n.statsBooksStartedThisYear,
        stretch: vertical,
      ),
      _StatTile(
        icon: Icons.library_books_rounded,
        iconColor: const Color(0xFFA855F7),
        value: '${state.totalSessions}',
        label: l10n.statsSessions,
        stretch: vertical,
      ),
    ];

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tiles[0]),
          const SizedBox(height: MokuSpacing.s2),
          Expanded(child: tiles[1]),
          const SizedBox(height: MokuSpacing.s2),
          Expanded(child: tiles[2]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: tiles[0]),
        const SizedBox(width: MokuSpacing.s3),
        Expanded(child: tiles[1]),
        const SizedBox(width: MokuSpacing.s3),
        Expanded(child: tiles[2]),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool stretch;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StatsSemanticNode(
      label: label,
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MokuSpacing.s4,
          vertical: MokuSpacing.s3,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: MokuRadius.lgAll,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: MokuRadius.smAll,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: MokuSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.literata(
                      fontSize: MokuTypeSize.h3,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(label,
                      style: MokuText.caption(
                          color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent sessions ───────────────────────────────────────────────────────────

class _RecentSessions extends StatelessWidget {
  final List<ReadingSession> sessions;
  const _RecentSessions({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StatsSemanticSection(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: MokuRadius.lgAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MokuSpacing.s4, MokuSpacing.s4,
                MokuSpacing.s4, MokuSpacing.s2,
              ),
              child: Text(
                context.l10n.statsRecentSessions,
                style: MokuText.bodySmall(
                  weight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const Divider(height: 1),
            ...sessions.map((s) => _SessionRow(session: s)),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ReadingSession session;
  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final localizations = MaterialLocalizations.of(context);
    final h = session.durationSeconds ~/ 3600;
    final m = (session.durationSeconds % 3600) ~/ 60;
    final duration = h > 0
        ? context.l10n.statsDurationHoursMinutes(hours: h, minutes: m)
        : context.l10n.statsDurationMinutes(minutes: m);
    final dateLabel =
        localizations.formatShortDate(session.startedAt);

    return StatsSemanticNode(
      label: session.bookTitle,
      value: '$dateLabel · $duration',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MokuSpacing.s4,
              vertical: MokuSpacing.s2 + 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    session.bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MokuText.bodySmall(),
                  ),
                ),
                const SizedBox(width: MokuSpacing.s4),
                Text(
                  dateLabel,
                  style: MokuText.caption(
                      color: colors.textSecondary),
                ),
                const SizedBox(width: MokuSpacing.s3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MokuSpacing.s2,
                      vertical: MokuSpacing.s1),
                  decoration: BoxDecoration(
                    color: colors.accentMuted
                        .withValues(alpha: 0.4),
                    borderRadius: MokuRadius.xsAll,
                  ),
                  child: Text(duration,
                      style: MokuText.micro(
                          color: colors.accent)),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: colors.border),
        ],
      ),
    );
  }
}
