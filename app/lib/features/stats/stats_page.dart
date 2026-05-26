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

          if (isDesktop) return _DesktopDashboard(state: state);

          // Mobile / tablet: single-column list
          return RefreshIndicator(
            onRefresh: () => context.read<StatsCubit>().load(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
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
                    _HeatmapCard(state: state),
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

// ── Desktop two-column dashboard ─────────────────────────────────────────────

class _DesktopDashboard extends StatelessWidget {
  final StatsState state;
  const _DesktopDashboard({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.statsTitle,
                  style: MokuText.pageHeading(),
                ),
                const SizedBox(height: MokuSpacing.s6),

                // Row 1: Streak (left) + 3 stat tiles stacked (right)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _Surface(
                          child: StreakCard(
                            currentStreak: state.currentStreak,
                            longestStreak: state.longestStreak,
                          ),
                        ),
                      ),
                      const SizedBox(width: MokuSpacing.s3),
                      Expanded(
                        flex: 3,
                        child: _SummaryRow(
                          state: state,
                          vertical: true,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MokuSpacing.s4),

                // Row 2: Activity heatmap
                _HeatmapCard(state: state),

                // Row 3: Recent sessions
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

// ── Shared surface container ──────────────────────────────────────────────────

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Surface({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: MokuRadius.lgAll,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );
  }
}

// ── Heatmap card ──────────────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  final StatsState state;
  const _HeatmapCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Surface(
      padding: const EdgeInsets.all(MokuSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ActivityHeatmap owns its own statsReadingActivity semantic header;
          // don't duplicate it here.
          const SizedBox(height: MokuSpacing.s3),
          ActivityHeatmap(dailyMinutes: state.dailyMinutes),
        ],
      ),
    );
  }
}

// ── Summary row (mobile) / column (desktop) ───────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final StatsState state;
  final bool vertical;

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
      ),
      _StatTile(
        icon: Icons.menu_book_rounded,
        iconColor: const Color(0xFF22C55E),
        value: '${state.booksReadThisYear}',
        label: l10n.statsBooksStartedThisYear,
      ),
      _StatTile(
        icon: Icons.library_books_rounded,
        iconColor: const Color(0xFFA855F7),
        value: '${state.totalSessions}',
        label: l10n.statsSessions,
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

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StatsSemanticNode(
      label: label,
      value: value,
      child: _Surface(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MokuSpacing.s4,
            vertical: MokuSpacing.s3,
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
                      style: GoogleFonts.instrumentSerif(
                        fontSize: MokuTypeSize.h3,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      label,
                      style: MokuText.caption(
                          color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final cs = Theme.of(context).colorScheme;

    return StatsSemanticSection(
      child: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MokuSpacing.s4, MokuSpacing.s4,
                MokuSpacing.s4, MokuSpacing.s2,
              ),
              child: StatsSemanticNode(
                label: context.l10n.statsRecentSessions,
                header: true,
                child: Text(
                  context.l10n.statsRecentSessions,
                  style: MokuText.sectionLabel(
                      color: cs.onSurfaceVariant),
                ),
              ),
            ),
            Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4)),
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
    final cs = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final h = session.durationSeconds ~/ 3600;
    final m = (session.durationSeconds % 3600) ~/ 60;
    final duration = h > 0
        ? context.l10n.statsDurationHoursMinutes(hours: h, minutes: m)
        : context.l10n.statsDurationMinutes(minutes: m);
    final dateLabel = localizations.formatShortDate(session.startedAt);

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
                      color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: MokuSpacing.s3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MokuSpacing.s2,
                      vertical: MokuSpacing.s1),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: MokuRadius.xsAll,
                  ),
                  child: Text(
                    duration,
                    style: MokuText.micro(
                        color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ],
      ),
    );
  }
}
