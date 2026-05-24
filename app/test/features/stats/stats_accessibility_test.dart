import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/database/database.dart';
import 'package:moku/features/stats/stats_page.dart';
import 'package:moku/features/stats/widgets/activity_heatmap.dart';
import 'package:moku/l10n/l10n.dart';

void main() {
  group('Stats accessibility', () {
    testWidgets('StatsPage exposes visible stats through semantics', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final yesterday = today.subtract(const Duration(days: 1));
      final database = _FakeAppDatabase([
        ReadingSession(
          id: 'session-1',
          bookId: 'book-1',
          bookTitle: 'Dune',
          startedAt: today,
          durationSeconds: 3600,
          startChapter: 1,
          endChapter: 2,
          updatedAt: today,
          syncPending: false,
        ),
        ReadingSession(
          id: 'session-2',
          bookId: 'book-2',
          bookTitle: 'Neuromancer',
          startedAt: yesterday,
          durationSeconds: 1800,
          startChapter: 3,
          endChapter: 4,
          updatedAt: yesterday,
          syncPending: false,
        ),
      ]);
      addTearDown(database.close);

      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _TestApp(
            child: RepositoryProvider<AppDatabase>.value(
              value: database,
              child: const StatsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(StatsPage));
        final l10n = AppLocalizations.of(context);
        final localizations = MaterialLocalizations.of(context);
        expect(
          tester.getSemantics(find.bySemanticsLabel(l10n.statsCurrentStreak)),
          _matchesReadOnlyNode(label: l10n.statsCurrentStreak, value: '2'),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(l10n.statsLongestStreak)),
          _matchesReadOnlyNode(label: l10n.statsLongestStreak, value: '2'),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(l10n.statsTotalTime)),
          _matchesReadOnlyNode(
            label: l10n.statsTotalTime,
            value: l10n.statsDurationHoursMinutes(hours: 1, minutes: 30),
          ),
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.statsBooksStartedThisYear),
          ),
          _matchesReadOnlyNode(
            label: l10n.statsBooksStartedThisYear,
            value: '2',
          ),
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.statsSessionCount(count: 2)),
          ),
          _matchesReadOnlyNode(
            label: l10n.statsSessionCount(count: 2),
            value: '2',
          ),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(l10n.statsRecentSessions)),
          _matchesReadOnlyNode(label: l10n.statsRecentSessions, isHeader: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Dune')),
          _matchesReadOnlyNode(
            label: 'Dune',
            value:
                '${localizations.formatShortDate(today)}, '
                '${l10n.statsDurationHoursMinutes(hours: 1, minutes: 0)}',
          ),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(l10n.statsReadingActivity)),
          _matchesReadOnlyNode(
            label: l10n.statsReadingActivity,
            isHeader: true,
          ),
        );
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('ActivityHeatmap exposes an empty-state semantics summary', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const _TestApp(
            child: Scaffold(
              body: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ActivityHeatmap(dailyMinutes: <DateTime, int>{}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ActivityHeatmap));
        final l10n = AppLocalizations.of(context);
        final localizations = MaterialLocalizations.of(context);
        final today = DateTime.now();
        final todayMidnight = DateTime(today.year, today.month, today.day);
        final emptySummary = l10n.statsHeatmapNoReading(
          date: localizations.formatShortDate(todayMidnight),
        );

        expect(find.semantics.byValue(emptySummary), findsOne);
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('ActivityHeatmap exposes visible reading days in semantics', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final firstVisibleDay = todayMidnight.subtract(
          const Duration(days: 370),
        );

        await tester.pumpWidget(
          _TestApp(
            child: Scaffold(
              body: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ActivityHeatmap(dailyMinutes: {firstVisibleDay: 25}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ActivityHeatmap));
        final l10n = AppLocalizations.of(context);
        final localizations = MaterialLocalizations.of(context);
        final visibleDayLabel = l10n.statsHeatmapMinutes(
          date: localizations.formatShortDate(firstVisibleDay),
          minutes: 25,
        );

        expect(
          tester.getSemantics(find.bySemanticsLabel(visibleDayLabel)),
          _matchesReadOnlyNode(label: visibleDayLabel),
        );
      } finally {
        semanticsHandle.dispose();
      }
    });
  });
}

Matcher _matchesReadOnlyNode({
  required String label,
  String? value,
  bool isHeader = false,
}) {
  return matchesSemantics(
    label: label,
    value: value,
    isHeader: isHeader,
    isFocusable: true,
    isReadOnly: true,
  );
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }
}

class _FakeAppDatabase extends AppDatabase {
  final List<ReadingSession> sessions;

  _FakeAppDatabase(this.sessions) : super(NativeDatabase.memory());

  @override
  Future<List<ReadingSession>> getAllSessions({
    bool includeDeleted = false,
  }) async => sessions;
}
