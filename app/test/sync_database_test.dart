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

  test('clearAllSyncContent wipes sync tables and returns local asset paths', () async {
    final now = DateTime.utc(2026, 5, 24, 10);
    await database.insertBook(
      BooksCompanion.insert(
        id: 'book-1',
        title: 'Seed Book',
        author: 'Author',
        filePath: '/tmp/book.epub',
        coverPath: const Value('/tmp/book-cover.png'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.upsertProgress(
      ReadingProgressesCompanion.insert(
        id: 'progress-1',
        bookId: 'book-1',
        lastReadAt: now,
        updatedAt: now,
      ),
    );
    await database.insertBookmark(
      BookmarksCompanion.insert(
        id: 'bookmark-1',
        bookId: 'book-1',
        chapterIndex: 0,
        title: 'Marker',
        createdAt: now,
        updatedAt: Value(now),
      ),
    );
    await database.insertHighlight(
      HighlightsCompanion.insert(
        id: 'highlight-1',
        bookId: 'book-1',
        chapterIndex: 0,
        selectedText: 'Highlight',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.insertCollection(
      BookCollectionsCompanion.insert(
        id: 'collection-1',
        name: 'Shelf',
        coverPath: const Value('/tmp/collection-cover.png'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.addBookToCollection('collection-1', 'book-1');
    await database.insertSession(
      ReadingSessionsCompanion.insert(
        id: 'session-1',
        bookId: 'book-1',
        bookTitle: 'Seed Book',
        startedAt: now,
        updatedAt: Value(now),
      ),
    );
    await database.upsertGoal(
      ReadingGoalsCompanion.insert(
        id: 'goal-1',
        year: 2026,
        booksGoal: const Value(24),
        minutesPerDayGoal: const Value(45),
        updatedAt: Value(now),
      ),
    );

    final assetPaths = await database.clearAllSyncContent();

    expect(assetPaths, containsAll([
      '/tmp/book.epub',
      '/tmp/book-cover.png',
      '/tmp/collection-cover.png',
    ]));
    expect(await database.getAllBooks(includeDeleted: true), isEmpty);
    expect(await database.getAllCollections(includeDeleted: true), isEmpty);
    expect(await database.getAllCollectionBooks(includeDeleted: true), isEmpty);
    expect(await database.getBookmarksForBook('book-1', includeDeleted: true), isEmpty);
    expect(await database.getHighlightsForBook('book-1', includeDeleted: true), isEmpty);
    expect(await database.getProgressForBook('book-1', includeDeleted: true), isNull);
    expect(await database.getAllSessions(includeDeleted: true), isEmpty);
    expect(await database.getAllGoals(includeDeleted: true), isEmpty);
  });
}
