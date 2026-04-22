import 'package:equatable/equatable.dart';

import '../../../core/database/database.dart';

enum StatsStatus { initial, loading, loaded, error }

class StatsState extends Equatable {
  final StatsStatus status;
  final List<ReadingSession> recentSessions;
  final int currentStreak;
  final int longestStreak;
  final int totalMinutes;
  final int totalSessions;
  final int booksReadThisYear;
  final Map<DateTime, int> dailyMinutes; // day → minutes
  final String? errorMessage;

  const StatsState({
    this.status = StatsStatus.initial,
    this.recentSessions = const [],
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalMinutes = 0,
    this.totalSessions = 0,
    this.booksReadThisYear = 0,
    this.dailyMinutes = const {},
    this.errorMessage,
  });

  StatsState copyWith({
    StatsStatus? status,
    List<ReadingSession>? recentSessions,
    int? currentStreak,
    int? longestStreak,
    int? totalMinutes,
    int? totalSessions,
    int? booksReadThisYear,
    Map<DateTime, int>? dailyMinutes,
    String? errorMessage,
  }) {
    return StatsState(
      status: status ?? this.status,
      recentSessions: recentSessions ?? this.recentSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      totalSessions: totalSessions ?? this.totalSessions,
      booksReadThisYear: booksReadThisYear ?? this.booksReadThisYear,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recentSessions,
        currentStreak,
        longestStreak,
        totalMinutes,
        totalSessions,
        booksReadThisYear,
        dailyMinutes,
        errorMessage,
      ];
}
