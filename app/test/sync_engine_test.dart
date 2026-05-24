import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moku/core/database/database.dart';
import 'package:moku/core/sync/sync_engine.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('SyncEngine.normalizeBookFormatName', () {
    test('prefers an explicit supported format', () {
      expect(
        SyncEngine.normalizeBookFormatName('pdf', filename: 'book.epub'),
        'pdf',
      );
    });

    test('falls back to the remote filename extension', () {
      expect(
        SyncEngine.normalizeBookFormatName('', filename: 'chapter.xhtml'),
        'html',
      );
      expect(
        SyncEngine.normalizeBookFormatName(null, filename: 'comic.cbz'),
        'cbz',
      );
    });

    test('defaults to epub for unknown input', () {
      expect(
        SyncEngine.normalizeBookFormatName('weird', filename: 'book.bin'),
        'epub',
      );
    });
  });

  group('SyncEngine entity sync', () {
    late AppDatabase database;
    late FakePocketBase pb;
    late SyncEngine engine;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      pb = FakePocketBase();
      engine = SyncEngine(pb: pb, db: database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> seedBook({
      String id = 'book-1',
      String remoteId = 'remote-book-1',
    }) async {
      final now = DateTime.utc(2026, 5, 24, 10);
      await database.insertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Seed Book',
          author: 'Author',
          filePath: '/tmp/book.epub',
          createdAt: now,
          updatedAt: now,
          remoteId: Value(remoteId),
        ),
        syncPending: false,
      );
    }

    test('pushes bookmarks and links the created remote id locally', () async {
      final now = DateTime.utc(2026, 5, 24, 10);
      await seedBook();
      await database.insertBookmark(
        BookmarksCompanion.insert(
          id: 'bookmark-1',
          bookId: 'book-1',
          chapterIndex: 2,
          title: 'Chapter 3',
          createdAt: now,
          updatedAt: Value(now),
          cfi: const Value('/6/2[ch3]'),
        ),
      );

      final result = await engine.syncAll();

      expect(result.isFullSuccess, isTrue);
      final localBookmark = await database.getBookmarksForBook('book-1');
      expect(localBookmark, hasLength(1));
      expect(localBookmark.single.remoteId, isNotEmpty);

      final remoteBookmarks = pb.recordsFor('bookmarks');
      expect(remoteBookmarks, hasLength(1));
      expect(remoteBookmarks.single.getStringValue('title'), 'Chapter 3');
      expect(remoteBookmarks.single.getStringValue('deleted_at'), isEmpty);
    });

    test(
      'reuses an existing remote bookmark instead of creating a duplicate',
      () async {
        final now = DateTime.utc(2026, 5, 24, 10);
        await seedBook(remoteId: 'remote-book-1');
        pb.seedRecords('bookmarks', [
          RecordModel({
            'id': 'bookmark-remote-1',
            'book': 'remote-book-1',
            'user': pb.userId,
            'chapter_index': 2,
            'cfi': '/6/2[ch3]',
            'title': 'Chapter 3',
            'deleted_at': '',
            'updated': now.toIso8601String(),
          }),
        ]);

        await database.insertBookmark(
          BookmarksCompanion.insert(
            id: 'bookmark-1',
            bookId: 'book-1',
            chapterIndex: 2,
            title: 'Chapter 3',
            createdAt: now.add(const Duration(minutes: 5)),
            updatedAt: Value(now.add(const Duration(minutes: 5))),
            cfi: const Value('/6/2[ch3]'),
          ),
        );

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        expect(pb.recordsFor('bookmarks'), hasLength(1));
        final localBookmark = await database.getBookmarksForBook('book-1');
        expect(localBookmark.single.remoteId, 'bookmark-remote-1');
        expect(localBookmark.single.syncPending, isFalse);
      },
    );

    test('pushes highlight tombstones to the remote backend', () async {
      final now = DateTime.utc(2026, 5, 24, 10);
      await seedBook();
      await database.insertHighlight(
        HighlightsCompanion.insert(
          id: 'highlight-1',
          bookId: 'book-1',
          chapterIndex: 1,
          selectedText: 'A highlighted passage',
          createdAt: now,
          updatedAt: now,
          color: const Value('#FFEB3B'),
        ),
      );

      final firstSync = await engine.syncAll();
      expect(firstSync.isFullSuccess, isTrue);

      await database.softDeleteHighlight('highlight-1');
      final secondSync = await engine.syncAll(lastSyncAt: firstSync.syncedAt);
      expect(secondSync.isFullSuccess, isTrue);

      final remoteHighlights = pb.recordsFor('highlights');
      expect(remoteHighlights, hasLength(1));
      expect(remoteHighlights.single.getStringValue('deleted_at'), isNotEmpty);
    });

    test(
      'revives an existing deleted remote highlight instead of creating a clone',
      () async {
        final now = DateTime.utc(2026, 5, 24, 10);
        await seedBook(remoteId: 'remote-book-1');
        pb.seedRecords('highlights', [
          RecordModel({
            'id': 'highlight-remote-1',
            'book': 'remote-book-1',
            'user': pb.userId,
            'chapter_index': 1,
            'start_cfi': '/6/2[start]',
            'end_cfi': '/6/2[end]',
            'selected_text': 'A highlighted passage',
            'color': '#FFEB3B',
            'note': '',
            'deleted_at': now.toIso8601String(),
            'updated': now.toIso8601String(),
          }),
        ]);

        await database.insertHighlight(
          HighlightsCompanion.insert(
            id: 'highlight-1',
            bookId: 'book-1',
            chapterIndex: 1,
            startCfi: const Value('/6/2[start]'),
            endCfi: const Value('/6/2[end]'),
            selectedText: 'A highlighted passage',
            createdAt: now.add(const Duration(minutes: 5)),
            updatedAt: now.add(const Duration(minutes: 5)),
            color: const Value('#FFEB3B'),
          ),
        );

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final remoteHighlights = pb.recordsFor('highlights');
        expect(remoteHighlights, hasLength(1));
        expect(remoteHighlights.single.id, 'highlight-remote-1');
        expect(remoteHighlights.single.getStringValue('deleted_at'), isEmpty);

        final localHighlights = await database.getHighlightsForBook('book-1');
        expect(localHighlights.single.remoteId, 'highlight-remote-1');
        expect(localHighlights.single.deletedAt, isNull);
        expect(localHighlights.single.syncPending, isFalse);
      },
    );

    test('book tombstones cascade to remote dependent records', () async {
      final now = DateTime.utc(2026, 5, 24, 10);
      await seedBook(remoteId: 'book-remote-1');

      pb.seedRecords('books', [
        RecordModel({
          'id': 'book-remote-1',
          'user': pb.userId,
          'title': 'Seed Book',
          'author': 'Author',
          'format': 'epub',
          'deleted_at': '',
          'updated': now.toIso8601String(),
        }),
      ]);
      pb.seedRecords('reading_progress', [
        RecordModel({
          'id': 'progress-remote-1',
          'book': 'book-remote-1',
          'user': pb.userId,
          'deleted_at': '',
          'updated': now.toIso8601String(),
        }),
      ]);
      pb.seedRecords('bookmarks', [
        RecordModel({
          'id': 'bookmark-remote-1',
          'book': 'book-remote-1',
          'user': pb.userId,
          'title': 'Chapter 1',
          'chapter_index': 0,
          'deleted_at': '',
          'updated': now.toIso8601String(),
        }),
      ]);
      pb.seedRecords('highlights', [
        RecordModel({
          'id': 'highlight-remote-1',
          'book': 'book-remote-1',
          'user': pb.userId,
          'selected_text': 'A highlight',
          'chapter_index': 0,
          'deleted_at': '',
          'updated': now.toIso8601String(),
        }),
      ]);
      pb.seedRecords('collection_books', [
        RecordModel({
          'id': 'link-remote-1',
          'book': 'book-remote-1',
          'collection': 'collection-remote-1',
          'sort_order': 0,
          'deleted_at': '',
          'updated': now.toIso8601String(),
        }),
      ]);

      await database.softDeleteBook('book-1');
      final result = await engine.syncAll();

      expect(result.isFullSuccess, isTrue);
      expect(
        pb.recordsFor('books').single.getStringValue('deleted_at'),
        isNotEmpty,
      );
      expect(
        pb.recordsFor('reading_progress').single.getStringValue('deleted_at'),
        isNotEmpty,
      );
      expect(
        pb.recordsFor('bookmarks').single.getStringValue('deleted_at'),
        isNotEmpty,
      );
      expect(
        pb.recordsFor('highlights').single.getStringValue('deleted_at'),
        isNotEmpty,
      );
      expect(
        pb.recordsFor('collection_books').single.getStringValue('deleted_at'),
        isNotEmpty,
      );
    });

    test('collection tombstones cascade to remote shelf links', () async {
      final now = DateTime.utc(2026, 5, 24, 10);
      await database.insertCollection(
        BookCollectionsCompanion.insert(
          id: 'collection-1',
          name: 'Favorites',
          createdAt: now,
          updatedAt: now,
          remoteId: const Value('collection-remote-1'),
        ),
        syncPending: false,
      );

      pb.seedRecords('collections', [
        RecordModel({
          'id': 'collection-remote-1',
          'user': pb.userId,
          'name': 'Favorites',
          'description': '',
          'deleted_at': '',
          'updated': now.toIso8601String(),
        }),
      ]);
      pb.seedRecords('collection_books', [
        RecordModel({
          'id': 'link-remote-1',
          'book': 'book-remote-1',
          'collection': 'collection-remote-1',
          'sort_order': 0,
          'deleted_at': '',
          'updated': now.toIso8601String(),
        }),
      ]);

      await database.softDeleteCollection('collection-1');
      final result = await engine.syncAll();

      expect(result.isFullSuccess, isTrue);
      expect(
        pb.recordsFor('collections').single.getStringValue('deleted_at'),
        isNotEmpty,
      );
      expect(
        pb.recordsFor('collection_books').single.getStringValue('deleted_at'),
        isNotEmpty,
      );
    });

    test(
      'attaches a remote reading progress record to the existing local book progress',
      () async {
        final localUpdated = DateTime.utc(2026, 5, 24, 10);
        final remoteUpdated = DateTime.utc(2026, 5, 24, 11);
        await seedBook(remoteId: 'book-remote-1');
        await database.upsertProgress(
          ReadingProgressesCompanion(
            id: const Value('progress-local'),
            bookId: const Value('book-1'),
            currentChapter: const Value(1),
            chapterProgress: const Value(0.2),
            overallProgress: const Value(0.2),
            lastReadAt: Value(localUpdated),
            updatedAt: Value(localUpdated),
          ),
        );

        pb.seedRecords('reading_progress', [
          RecordModel({
            'id': 'progress-remote-1',
            'book': 'book-remote-1',
            'user': pb.userId,
            'current_chapter': 5,
            'chapter_progress': 0.75,
            'overall_progress': 0.9,
            'last_position': 'cfi(/6/8)',
            'last_read_at': remoteUpdated.toIso8601String(),
            'deleted_at': '',
            'updated': remoteUpdated.toIso8601String(),
          }),
        ]);

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final progressRows = await database
            .select(database.readingProgresses)
            .get();
        expect(progressRows, hasLength(1));
        final progress = progressRows.single;
        expect(progress.id, 'progress-local');
        expect(progress.remoteId, 'progress-remote-1');
        expect(progress.currentChapter, 5);
        expect(progress.overallProgress, closeTo(0.9, 0.0001));
      },
    );

    test(
      'pushes a newer local reading progress into an existing remote record',
      () async {
        final remoteUpdated = DateTime.utc(2026, 5, 24, 10);
        final localUpdated = DateTime.utc(2026, 5, 24, 11);
        await seedBook(remoteId: 'book-remote-1');
        await database.upsertProgress(
          ReadingProgressesCompanion(
            id: const Value('progress-local'),
            bookId: const Value('book-1'),
            currentChapter: const Value(7),
            chapterProgress: const Value(0.8),
            overallProgress: const Value(0.8),
            lastPosition: const Value('cfi(/6/10)'),
            lastReadAt: Value(localUpdated),
            updatedAt: Value(localUpdated),
          ),
        );

        pb.seedRecords('reading_progress', [
          RecordModel({
            'id': 'progress-remote-1',
            'book': 'book-remote-1',
            'user': pb.userId,
            'current_chapter': 2,
            'chapter_progress': 0.1,
            'overall_progress': 0.1,
            'last_position': 'cfi(/6/2)',
            'last_read_at': remoteUpdated.toIso8601String(),
            'deleted_at': '',
            'updated': remoteUpdated.toIso8601String(),
          }),
        ]);

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final progress =
            (await database.select(database.readingProgresses).get()).single;
        expect(progress.remoteId, 'progress-remote-1');
        expect(progress.currentChapter, 7);
        expect(progress.overallProgress, closeTo(0.8, 0.0001));
        expect(progress.syncPending, isFalse);

        final remote = pb.recordsFor('reading_progress').single;
        expect(remote.id, 'progress-remote-1');
        expect(remote.getIntValue('current_chapter'), 7);
        expect(remote.getDoubleValue('overall_progress'), closeTo(0.8, 0.0001));
      },
    );

    test(
      'attaches a remote reading session to the existing local session instead of duplicating it',
      () async {
        final startedAt = DateTime.utc(2026, 5, 24, 10);
        final remoteUpdated = DateTime.utc(2026, 5, 24, 12);
        await seedBook(remoteId: 'book-remote-1');
        await database.insertSession(
          ReadingSessionsCompanion.insert(
            id: 'session-local',
            bookId: 'book-1',
            bookTitle: 'Seed Book',
            startedAt: startedAt,
            endedAt: Value(startedAt.add(const Duration(minutes: 20))),
            durationSeconds: const Value(1200),
            startChapter: const Value(1),
            endChapter: const Value(2),
            updatedAt: Value(DateTime.utc(2026, 5, 24, 10, 30)),
          ),
        );

        pb.seedRecords('reading_sessions', [
          RecordModel({
            'id': 'session-remote-1',
            'book': 'book-remote-1',
            'user': pb.userId,
            'book_title': 'Seed Book',
            'started_at': startedAt.toIso8601String(),
            'ended_at': startedAt
                .add(const Duration(minutes: 45))
                .toIso8601String(),
            'duration_seconds': 2700,
            'start_chapter': 1,
            'end_chapter': 4,
            'deleted_at': '',
            'updated': remoteUpdated.toIso8601String(),
          }),
        ]);

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final sessions = await database.getAllSessions(includeDeleted: true);
        expect(sessions, hasLength(1));
        final session = sessions.single;
        expect(session.id, 'session-local');
        expect(session.remoteId, 'session-remote-1');
        expect(session.durationSeconds, 2700);
        expect(session.endChapter, 4);
      },
    );

    test(
      'pushes a newer local reading session into an existing remote record',
      () async {
        final startedAt = DateTime.utc(2026, 5, 24, 10);
        final remoteUpdated = DateTime.utc(2026, 5, 24, 10, 15);
        final localUpdated = DateTime.utc(2026, 5, 24, 11);
        await seedBook(remoteId: 'book-remote-1');
        await database.insertSession(
          ReadingSessionsCompanion.insert(
            id: 'session-local',
            bookId: 'book-1',
            bookTitle: 'Seed Book',
            startedAt: startedAt,
            endedAt: Value(startedAt.add(const Duration(minutes: 20))),
            durationSeconds: const Value(1200),
            startChapter: const Value(3),
            endChapter: const Value(5),
            updatedAt: Value(localUpdated),
          ),
        );

        pb.seedRecords('reading_sessions', [
          RecordModel({
            'id': 'session-remote-1',
            'book': 'book-remote-1',
            'user': pb.userId,
            'book_title': 'Seed Book',
            'started_at': startedAt.toIso8601String(),
            'ended_at': startedAt
                .add(const Duration(minutes: 10))
                .toIso8601String(),
            'duration_seconds': 600,
            'start_chapter': 1,
            'end_chapter': 2,
            'deleted_at': '',
            'updated': remoteUpdated.toIso8601String(),
          }),
        ]);

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final session = (await database.getAllSessions(
          includeDeleted: true,
        )).single;
        expect(session.remoteId, 'session-remote-1');
        expect(session.durationSeconds, 1200);
        expect(session.startChapter, 3);
        expect(session.endChapter, 5);
        expect(session.syncPending, isFalse);

        final remote = pb.recordsFor('reading_sessions').single;
        expect(remote.id, 'session-remote-1');
        expect(remote.getIntValue('duration_seconds'), 1200);
        expect(remote.getIntValue('start_chapter'), 3);
        expect(remote.getIntValue('end_chapter'), 5);
      },
    );

    test(
      'does not merge distinct reading sessions that start close together',
      () async {
        final firstStart = DateTime.utc(2026, 5, 24, 10, 0, 0);
        final secondStart = firstStart.add(const Duration(seconds: 45));
        await seedBook(remoteId: 'book-remote-1');

        await database.insertSession(
          ReadingSessionsCompanion.insert(
            id: 'session-local-1',
            bookId: 'book-1',
            bookTitle: 'Seed Book',
            startedAt: firstStart,
            endedAt: Value(firstStart.add(const Duration(minutes: 5))),
            durationSeconds: const Value(300),
            startChapter: const Value(1),
            endChapter: const Value(1),
            updatedAt: Value(firstStart),
            remoteId: const Value('session-remote-1'),
          ),
          syncPending: false,
        );

        pb.seedRecords('reading_sessions', [
          RecordModel({
            'id': 'session-remote-1',
            'book': 'book-remote-1',
            'user': pb.userId,
            'book_title': 'Seed Book',
            'started_at': firstStart.toIso8601String(),
            'ended_at': firstStart
                .add(const Duration(minutes: 5))
                .toIso8601String(),
            'duration_seconds': 300,
            'start_chapter': 1,
            'end_chapter': 1,
            'deleted_at': '',
            'updated': firstStart.toIso8601String(),
          }),
          RecordModel({
            'id': 'session-remote-2',
            'book': 'book-remote-1',
            'user': pb.userId,
            'book_title': 'Seed Book',
            'started_at': secondStart.toIso8601String(),
            'ended_at': secondStart
                .add(const Duration(minutes: 12))
                .toIso8601String(),
            'duration_seconds': 720,
            'start_chapter': 2,
            'end_chapter': 3,
            'deleted_at': '',
            'updated': secondStart.toIso8601String(),
          }),
        ]);

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final sessions = await database.getAllSessions(includeDeleted: true);
        expect(sessions, hasLength(2));
        expect(
          sessions.where((s) => s.remoteId == 'session-remote-2'),
          hasLength(1),
        );
      },
    );

    test(
      'attaches a remote reading goal to the existing local year entry instead of duplicating it',
      () async {
        final localUpdated = DateTime.utc(2026, 5, 24, 10);
        final remoteUpdated = DateTime.utc(2026, 5, 24, 13);
        await database.upsertGoal(
          ReadingGoalsCompanion.insert(
            id: 'goal-local',
            year: 2026,
            booksGoal: const Value(12),
            minutesPerDayGoal: const Value(30),
            updatedAt: Value(localUpdated),
          ),
        );

        pb.seedRecords('reading_goals', [
          RecordModel({
            'id': 'goal-remote-1',
            'user': pb.userId,
            'year': 2026,
            'books_goal': 24,
            'minutes_per_day_goal': 45,
            'deleted_at': '',
            'updated': remoteUpdated.toIso8601String(),
          }),
        ]);

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final goals = await database.getAllGoals(includeDeleted: true);
        expect(goals, hasLength(1));
        final goal = goals.single;
        expect(goal.id, 'goal-local');
        expect(goal.remoteId, 'goal-remote-1');
        expect(goal.booksGoal, 24);
        expect(goal.minutesPerDayGoal, 45);
      },
    );

    test(
      'revives a deleted remote reading goal when the user recreates it locally',
      () async {
        final deletedAt = DateTime.utc(2026, 5, 24, 10);
        final recreatedAt = DateTime.utc(2026, 5, 24, 11);
        pb.seedRecords('reading_goals', [
          RecordModel({
            'id': 'goal-remote-1',
            'user': pb.userId,
            'year': 2026,
            'books_goal': 12,
            'minutes_per_day_goal': 30,
            'deleted_at': deletedAt.toIso8601String(),
            'updated': deletedAt.toIso8601String(),
          }),
        ]);

        await database.upsertGoal(
          ReadingGoalsCompanion.insert(
            id: 'goal-local',
            year: 2026,
            booksGoal: const Value(24),
            minutesPerDayGoal: const Value(45),
            updatedAt: Value(recreatedAt),
          ),
        );

        final result = await engine.syncAll();

        expect(result.isFullSuccess, isTrue);
        final goals = await database.getAllGoals(includeDeleted: true);
        expect(goals, hasLength(1));
        final goal = goals.single;
        expect(goal.id, 'goal-local');
        expect(goal.remoteId, 'goal-remote-1');
        expect(goal.deletedAt, isNull);
        expect(goal.booksGoal, 24);
        expect(goal.minutesPerDayGoal, 45);
        expect(goal.syncPending, isFalse);

        final remoteGoal = pb.recordsFor('reading_goals').single;
        expect(remoteGoal.id, 'goal-remote-1');
        expect(remoteGoal.getStringValue('deleted_at'), isEmpty);
        expect(remoteGoal.getIntValue('books_goal'), 24);
        expect(remoteGoal.getIntValue('minutes_per_day_goal'), 45);
      },
    );
  });
}

class FakePocketBase extends PocketBase {
  FakePocketBase({this.userId = 'user-1'}) : super('http://127.0.0.1:8090') {
    authStore.save(
      'test-token',
      RecordModel({'id': userId, 'collectionName': 'users'}),
    );
  }

  final String userId;
  final Map<String, List<RecordModel>> _records = <String, List<RecordModel>>{};
  final Map<String, FakeRecordService> _services =
      <String, FakeRecordService>{};
  int _nextId = 1;

  @override
  RecordService collection(String collectionIdOrName) {
    return _services.putIfAbsent(
      collectionIdOrName,
      () => FakeRecordService(
        this,
        collectionIdOrName,
        _records.putIfAbsent(collectionIdOrName, () => <RecordModel>[]),
      ),
    );
  }

  List<RecordModel> recordsFor(String collection) {
    return List<RecordModel>.unmodifiable(
      _records.putIfAbsent(collection, () => <RecordModel>[]),
    );
  }

  void seedRecords(String collection, List<RecordModel> records) {
    _records[collection] = records
        .map((record) => RecordModel(Map<String, dynamic>.from(record.data)))
        .toList();
    _services.remove(collection);
  }

  String nextRecordId(String collection) => '$collection-${_nextId++}';

  String nextTimestamp() {
    final value = DateTime.utc(2026, 5, 24, 14, _nextId);
    _nextId++;
    return value.toIso8601String();
  }
}

class FakeRecordService extends RecordService {
  FakeRecordService(this._pb, String collection, this._records)
    : _collection = collection,
      super(_pb, collection);

  final FakePocketBase _pb;
  final String _collection;
  final List<RecordModel> _records;

  @override
  Future<RecordAuth> authRefresh({
    String? expand,
    String? fields,
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    return RecordAuth(token: _pb.authStore.token, record: _pb.authStore.record);
  }

  @override
  Future<ResultList<RecordModel>> getList({
    int page = 1,
    int perPage = 30,
    bool skipTotal = false,
    String? expand,
    String? filter,
    String? sort,
    String? fields,
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    final filtered = _records
        .where((record) => _matchesFilter(record, filter))
        .toList(growable: false);
    final start = ((page - 1) * perPage).clamp(0, filtered.length);
    final end = (start + perPage).clamp(0, filtered.length);
    final items = filtered.sublist(start, end);
    return ResultList<RecordModel>(
      page: page,
      perPage: perPage,
      totalItems: filtered.length,
      totalPages: filtered.isEmpty ? 0 : ((filtered.length - 1) ~/ perPage) + 1,
      items: items,
    );
  }

  @override
  Future<RecordModel> create({
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    List<http.MultipartFile> files = const [],
    Map<String, String> headers = const {},
    String? expand,
    String? fields,
  }) async {
    final timestamp = _pb.nextTimestamp();
    final created = RecordModel({
      ...body,
      'id': _pb.nextRecordId(_collection),
      'updated': timestamp,
      'created': timestamp,
    });
    _records.add(created);
    return created;
  }

  @override
  Future<RecordModel> update(
    String id, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    List<http.MultipartFile> files = const [],
    Map<String, String> headers = const {},
    String? expand,
    String? fields,
  }) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) {
      throw ClientException(
        statusCode: 404,
        response: const {'code': 404, 'message': 'Not found', 'data': {}},
      );
    }
    final updated = RecordModel({
      ..._records[index].data,
      ...body,
      'id': id,
      'updated': _pb.nextTimestamp(),
    });
    _records[index] = updated;
    return updated;
  }

  bool _matchesFilter(RecordModel record, String? filter) {
    if (filter == null || filter.trim().isEmpty) return true;

    final clauses = filter
        .split('&&')
        .map((clause) => clause.trim())
        .where((clause) => clause.isNotEmpty);
    for (final clause in clauses) {
      final match = RegExp(r'^([A-Za-z0-9_]+)\s*=\s*(.+)$').firstMatch(clause);
      if (match == null) return false;

      final field = match.group(1)!;
      var expected = match.group(2)!.trim();
      if (expected.startsWith("'") && expected.endsWith("'")) {
        expected = expected.substring(1, expected.length - 1);
      }
      expected = expected.replaceAll("\\'", "'");

      final actual = record.data[field];
      if (_matchesDateTime(actual, expected)) continue;
      if ((actual ?? '').toString() != expected) return false;
    }
    return true;
  }

  bool _matchesDateTime(dynamic actual, String expected) {
    final actualString = actual?.toString();
    if (actualString == null || actualString.isEmpty) return false;
    final actualDate = DateTime.tryParse(actualString)?.toUtc();
    final expectedDate = DateTime.tryParse(expected)?.toUtc();
    return actualDate != null &&
        expectedDate != null &&
        actualDate == expectedDate;
  }
}
