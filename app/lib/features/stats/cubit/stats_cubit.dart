import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database.dart';
import 'stats_state.dart';

class StatsCubit extends Cubit<StatsState> {
  final AppDatabase _database;

  StatsCubit({required AppDatabase database})
      : _database = database,
        super(const StatsState());

  Future<void> load() async {
    emit(state.copyWith(status: StatsStatus.loading));

    try {
      final sessions = await _database.getAllSessions();
      final computed = _compute(sessions);
      emit(state.copyWith(
        status: StatsStatus.loaded,
        recentSessions: sessions.take(20).toList(),
        currentStreak: computed.currentStreak,
        longestStreak: computed.longestStreak,
        totalMinutes: computed.totalMinutes,
        totalSessions: sessions.length,
        booksReadThisYear: computed.booksReadThisYear,
        dailyMinutes: computed.dailyMinutes,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: StatsStatus.error,
        errorMessage: 'Failed to load stats: $e',
      ));
    }
  }

  _ComputedStats _compute(List<ReadingSession> sessions) {
    final totalMinutes =
        sessions.fold(0, (sum, s) => sum + s.durationSeconds) ~/ 60;

    // Build daily activity map (normalised to local midnight)
    final Map<DateTime, int> byDay = {};
    for (final s in sessions) {
      final day =
          DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      byDay[day] = (byDay[day] ?? 0) + s.durationSeconds ~/ 60;
    }

    final streaks = _computeStreaks(byDay);

    // Count books with ≥10 minutes of reading this year (meaningful engagement)
    final year = DateTime.now().year;
    final Map<String, int> minutesByBook = {};
    for (final s in sessions.where((s) => s.startedAt.year == year)) {
      minutesByBook[s.bookId] =
          (minutesByBook[s.bookId] ?? 0) + s.durationSeconds ~/ 60;
    }
    final booksReadThisYear =
        minutesByBook.values.where((m) => m >= 10).length;

    return _ComputedStats(
      totalMinutes: totalMinutes,
      dailyMinutes: byDay,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
      booksReadThisYear: booksReadThisYear,
    );
  }

  /// Computes current and longest reading streaks from a day→minutes map.
  /// The current streak is only non-zero if the most recent reading day is
  /// today or yesterday (streak still active).
  ({int current, int longest}) _computeStreaks(Map<DateTime, int> byDay) {
    if (byDay.isEmpty) return (current: 0, longest: 0);

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    final daysSinceMostRecent =
        todayMidnight.difference(days[0]).inDays;

    int leadingRun = 1; // consecutive days from the most recent
    bool leadingEnded = false;
    int run = 1;
    int longest = 0;

    for (int i = 1; i < days.length; i++) {
      final diff = days[i - 1].difference(days[i]).inDays;
      if (diff == 1) {
        run++;
        if (!leadingEnded) leadingRun++;
      } else {
        longest = run > longest ? run : longest;
        leadingEnded = true;
        run = 1;
      }
    }
    longest = run > longest ? run : longest;

    final current = daysSinceMostRecent <= 1 ? leadingRun : 0;
    return (current: current, longest: longest);
  }
}

class _ComputedStats {
  final int totalMinutes;
  final Map<DateTime, int> dailyMinutes;
  final int currentStreak;
  final int longestStreak;
  final int booksReadThisYear;

  _ComputedStats({
    required this.totalMinutes,
    required this.dailyMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.booksReadThisYear,
  });
}
