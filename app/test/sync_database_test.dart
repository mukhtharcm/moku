import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/database/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedBook({String id = 'book-1'}) async {
    final now = DateTime.utc(2026, 5, 24, 10);
    await database.insertBook(
      BooksCompanion.insert(
        id: id,
        title: 'Seed Book',
        author: 'Author',
        filePath: '/tmp/book.epub',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test(
    'soft-deleted reading sessions are hidden from default queries',
    () async {
      final startedAt = DateTime.utc(2026, 5, 24, 10);
      final deletedAt = DateTime.utc(2026, 5, 24, 11);
      await seedBook();

      await database.insertSession(
        ReadingSessionsCompanion.insert(
          id: 'session-1',
          bookId: 'book-1',
          bookTitle: 'Seed Book',
          startedAt: startedAt,
          endedAt: Value(startedAt.add(const Duration(minutes: 45))),
          durationSeconds: const Value(2700),
          updatedAt: Value(startedAt),
        ),
      );

      expect(await database.getAllSessions(), hasLength(1));

      await database.softDeleteSession('session-1', deletedAt: deletedAt);

      expect(await database.getAllSessions(), isEmpty);
      final deletedSessions = await database.getAllSessions(
        includeDeleted: true,
      );
      expect(deletedSessions, hasLength(1));
      expect(deletedSessions.single.deletedAt?.toUtc(), deletedAt);
    },
  );

  test('soft-deleted reading goals are hidden from default lookups', () async {
    final updatedAt = DateTime.utc(2026, 5, 24, 10);
    final deletedAt = DateTime.utc(2026, 5, 24, 11);

    await database.upsertGoal(
      ReadingGoalsCompanion.insert(
        id: 'goal-1',
        year: 2026,
        booksGoal: const Value(24),
        minutesPerDayGoal: const Value(45),
        updatedAt: Value(updatedAt),
      ),
    );

    expect((await database.getGoalForYear(2026))?.deletedAt, isNull);

    await database.softDeleteGoal('goal-1', deletedAt: deletedAt);

    expect(await database.getGoalForYear(2026), isNull);
    final deletedGoal = await database.getGoalForYear(
      2026,
      includeDeleted: true,
    );
    expect(deletedGoal?.deletedAt?.toUtc(), deletedAt);
  });
}
