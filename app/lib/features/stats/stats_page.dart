import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/database/database.dart';
import '../../l10n/l10n.dart';
import 'cubit/stats_cubit.dart';
import 'cubit/stats_state.dart';
import 'widgets/streak_card.dart';
import 'widgets/activity_heatmap.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle), centerTitle: false),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state.status == StatsStatus.loading ||
              state.status == StatsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == StatsStatus.error) {
            return Center(child: Text(l10n.statsErrorFallback));
          }
          return RefreshIndicator(
            onRefresh: () => context.read<StatsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StreakCard(
                  currentStreak: state.currentStreak,
                  longestStreak: state.longestStreak,
                ),
                const SizedBox(height: 16),
                _SummaryCards(state: state),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ActivityHeatmap(dailyMinutes: state.dailyMinutes),
                  ),
                ),
                if (state.recentSessions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _RecentSessions(sessions: state.recentSessions),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final StatsState state;
  const _SummaryCards({required this.state});

  @override
  Widget build(BuildContext context) {
    final h = state.totalMinutes ~/ 60;
    final m = state.totalMinutes % 60;
    final l10n = context.l10n;
    final timeLabel = h > 0
        ? l10n.statsDurationHoursMinutes(hours: h, minutes: m)
        : l10n.statsDurationMinutes(minutes: m);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            iconColor: Colors.blue,
            value: timeLabel,
            label: l10n.statsTotalTime,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book_rounded,
            iconColor: Colors.green,
            value: '${state.booksReadThisYear}',
            label: l10n.statsBooksStartedThisYear,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.library_books_rounded,
            iconColor: Colors.purple,
            value: '${state.totalSessions}',
            label: l10n.statsSessions,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RecentSessions extends StatelessWidget {
  final List<ReadingSession> sessions;
  const _RecentSessions({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.statsRecentSessions,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...sessions.map((s) => _SessionTile(session: s)),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ReadingSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final h = session.durationSeconds ~/ 3600;
    final m = (session.durationSeconds % 3600) ~/ 60;
    final duration = h > 0
        ? context.l10n.statsDurationHoursMinutes(hours: h, minutes: m)
        : context.l10n.statsDurationMinutes(minutes: m);
    final date = session.startedAt;
    final dateLabel = localizations.formatShortDate(date);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            session.bookTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(dateLabel),
          trailing: Chip(
            label: Text(duration, style: theme.textTheme.bodySmall),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
