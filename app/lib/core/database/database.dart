import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Books,
    ReadingProgresses,
    Bookmarks,
    Highlights,
    BookCollections,
    CollectionBooks,
    ReadingSessions,
    ReadingGoals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 7) {
        await _repairLegacySchema(migrator);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'moku_db');
  }

  Future<void> _repairLegacySchema(Migrator migrator) async {
    await _ensureTable(migrator, readingSessions, 'reading_sessions');
    await _ensureTable(migrator, readingGoals, 'reading_goals');

    await _ensureColumn(migrator, books, books.format, 'books', 'format');
    await _ensureColumn(
      migrator,
      books,
      books.deletedAt,
      'books',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      books,
      books.syncPending,
      'books',
      'sync_pending',
    );
    await _ensureColumn(migrator, books, books.remoteId, 'books', 'remote_id');

    await _ensureColumn(
      migrator,
      readingProgresses,
      readingProgresses.deletedAt,
      'reading_progresses',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      readingProgresses,
      readingProgresses.syncPending,
      'reading_progresses',
      'sync_pending',
    );
    await _ensureColumn(
      migrator,
      readingProgresses,
      readingProgresses.remoteId,
      'reading_progresses',
      'remote_id',
    );

    await _ensureColumn(
      migrator,
      bookmarks,
      bookmarks.updatedAt,
      'bookmarks',
      'updated_at',
    );
    await _ensureColumn(
      migrator,
      bookmarks,
      bookmarks.deletedAt,
      'bookmarks',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      bookmarks,
      bookmarks.syncPending,
      'bookmarks',
      'sync_pending',
    );
    await _ensureColumn(
      migrator,
      bookmarks,
      bookmarks.remoteId,
      'bookmarks',
      'remote_id',
    );

    await _ensureColumn(
      migrator,
      highlights,
      highlights.deletedAt,
      'highlights',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      highlights,
      highlights.syncPending,
      'highlights',
      'sync_pending',
    );
    await _ensureColumn(
      migrator,
      highlights,
      highlights.remoteId,
      'highlights',
      'remote_id',
    );

    await _ensureColumn(
      migrator,
      bookCollections,
      bookCollections.deletedAt,
      'book_collections',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      bookCollections,
      bookCollections.syncPending,
      'book_collections',
      'sync_pending',
    );
    await _ensureColumn(
      migrator,
      bookCollections,
      bookCollections.remoteId,
      'book_collections',
      'remote_id',
    );

    await _ensureColumn(
      migrator,
      collectionBooks,
      collectionBooks.remoteId,
      'collection_books',
      'remote_id',
    );
    await _ensureColumn(
      migrator,
      collectionBooks,
      collectionBooks.updatedAt,
      'collection_books',
      'updated_at',
    );
    await _ensureColumn(
      migrator,
      collectionBooks,
      collectionBooks.deletedAt,
      'collection_books',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      collectionBooks,
      collectionBooks.syncPending,
      'collection_books',
      'sync_pending',
    );

    await _ensureColumn(
      migrator,
      readingSessions,
      readingSessions.updatedAt,
      'reading_sessions',
      'updated_at',
    );
    await _ensureColumn(
      migrator,
      readingSessions,
      readingSessions.deletedAt,
      'reading_sessions',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      readingSessions,
      readingSessions.syncPending,
      'reading_sessions',
      'sync_pending',
    );
    await _ensureColumn(
      migrator,
      readingSessions,
      readingSessions.remoteId,
      'reading_sessions',
      'remote_id',
    );

    await _ensureColumn(
      migrator,
      readingGoals,
      readingGoals.updatedAt,
      'reading_goals',
      'updated_at',
    );
    await _ensureColumn(
      migrator,
      readingGoals,
      readingGoals.deletedAt,
      'reading_goals',
      'deleted_at',
    );
    await _ensureColumn(
      migrator,
      readingGoals,
      readingGoals.syncPending,
      'reading_goals',
      'sync_pending',
    );
    await _ensureColumn(
      migrator,
      readingGoals,
      readingGoals.remoteId,
      'reading_goals',
      'remote_id',
    );
  }

  Future<void> _ensureTable<T extends Table, D>(
    Migrator migrator,
    TableInfo<T, D> table,
    String tableName,
  ) async {
    if (await _tableExists(tableName)) return;
    await migrator.createTable(table);
  }

  Future<void> _ensureColumn<T extends Table, D>(
    Migrator migrator,
    TableInfo<T, D> table,
    GeneratedColumn column,
    String tableName,
    String columnName,
  ) async {
    if (await _columnExists(tableName, columnName)) return;
    await migrator.addColumn(table, column);
  }

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      variables: [Variable.withString('table'), Variable.withString(tableName)],
    ).getSingleOrNull();
    return result != null;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    for (final row in rows) {
      if (row.read<String>('name') == columnName) {
        return true;
      }
    }
    return false;
  }

  // --- Book queries ---
  Future<List<Book>> getAllBooks({bool includeDeleted = false}) {
    final query = select(books);
    if (!includeDeleted) {
      query.where((b) => b.deletedAt.isNull());
    }
    return query.get();
  }

  Stream<List<Book>> watchAllBooks({bool includeDeleted = false}) {
    final query = select(books);
    if (!includeDeleted) {
      query.where((b) => b.deletedAt.isNull());
    }
    return query.watch();
  }

  /// Fetch a single book by its local ID, including file and cover paths.
  /// Use this before deleting a book so you can clean up files on disk.
  Future<Book?> getBookById(String id, {bool includeDeleted = false}) {
    final query = select(books)..where((b) => b.id.equals(id));
    if (!includeDeleted) {
      query.where((b) => b.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  Future<int> insertBook(BooksCompanion book, {bool syncPending = true}) =>
      into(books).insert(book.copyWith(syncPending: Value(syncPending)));

  Future<bool> updateBook(BooksCompanion book, {bool syncPending = true}) =>
      update(books).replace(book.copyWith(syncPending: Value(syncPending)));

  Future<void> softDeleteBook(
    String id, {
    DateTime? deletedAt,
    bool markPending = true,
  }) async {
    final timestamp = deletedAt ?? DateTime.now();
    await transaction(() async {
      await (update(
        books,
      )..where((b) => b.id.equals(id) & b.deletedAt.isNull())).write(
        BooksCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncPending: Value(markPending),
        ),
      );
      await (update(
        readingProgresses,
      )..where((p) => p.bookId.equals(id) & p.deletedAt.isNull())).write(
        ReadingProgressesCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncPending: Value(markPending),
        ),
      );
      await (update(
        bookmarks,
      )..where((b) => b.bookId.equals(id) & b.deletedAt.isNull())).write(
        BookmarksCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncPending: Value(markPending),
        ),
      );
      await (update(
        highlights,
      )..where((h) => h.bookId.equals(id) & h.deletedAt.isNull())).write(
        HighlightsCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncPending: Value(markPending),
        ),
      );
      await (update(
        collectionBooks,
      )..where((cb) => cb.bookId.equals(id) & cb.deletedAt.isNull())).write(
        CollectionBooksCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncPending: Value(markPending),
        ),
      );
    });
  }

  // --- Reading progress queries ---
  Future<ReadingProgress?> getProgressForBook(
    String bookId, {
    bool includeDeleted = false,
  }) {
    final query = select(readingProgresses)
      ..where((p) => p.bookId.equals(bookId))
      ..limit(1);
    if (!includeDeleted) {
      query.where((p) => p.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  Stream<ReadingProgress?> watchProgressForBook(
    String bookId, {
    bool includeDeleted = false,
  }) {
    final query = select(readingProgresses)
      ..where((p) => p.bookId.equals(bookId))
      ..limit(1);
    if (!includeDeleted) {
      query.where((p) => p.deletedAt.isNull());
    }
    return query.watchSingleOrNull();
  }

  Future<int> upsertProgress(
    ReadingProgressesCompanion progress, {
    bool syncPending = true,
  }) => into(
    readingProgresses,
  ).insertOnConflictUpdate(progress.copyWith(syncPending: Value(syncPending)));

  // --- Bookmark queries ---
  Future<List<Bookmark>> getBookmarksForBook(
    String bookId, {
    bool includeDeleted = false,
  }) {
    final query = select(bookmarks)
      ..where((b) => b.bookId.equals(bookId))
      ..orderBy([(b) => OrderingTerm.asc(b.chapterIndex)]);
    if (!includeDeleted) {
      query.where((b) => b.deletedAt.isNull());
    }
    return query.get();
  }

  Stream<List<Bookmark>> watchBookmarksForBook(
    String bookId, {
    bool includeDeleted = false,
  }) {
    final query = select(bookmarks)
      ..where((b) => b.bookId.equals(bookId))
      ..orderBy([(b) => OrderingTerm.asc(b.chapterIndex)]);
    if (!includeDeleted) {
      query.where((b) => b.deletedAt.isNull());
    }
    return query.watch();
  }

  Future<int> insertBookmark(
    BookmarksCompanion bookmark, {
    bool syncPending = true,
  }) => into(
    bookmarks,
  ).insert(bookmark.copyWith(syncPending: Value(syncPending)));

  Future<void> softDeleteBookmark(
    String id, {
    DateTime? deletedAt,
    bool markPending = true,
  }) async {
    final timestamp = deletedAt ?? DateTime.now();
    await (update(
      bookmarks,
    )..where((b) => b.id.equals(id) & b.deletedAt.isNull())).write(
      BookmarksCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
        syncPending: Value(markPending),
      ),
    );
  }

  // --- Highlight queries ---
  Future<List<Highlight>> getHighlightsForBook(
    String bookId, {
    bool includeDeleted = false,
  }) {
    final query = select(highlights)
      ..where((h) => h.bookId.equals(bookId))
      ..orderBy([(h) => OrderingTerm.asc(h.chapterIndex)]);
    if (!includeDeleted) {
      query.where((h) => h.deletedAt.isNull());
    }
    return query.get();
  }

  Stream<List<Highlight>> watchHighlightsForBook(
    String bookId, {
    bool includeDeleted = false,
  }) {
    final query = select(highlights)
      ..where((h) => h.bookId.equals(bookId))
      ..orderBy([(h) => OrderingTerm.asc(h.chapterIndex)]);
    if (!includeDeleted) {
      query.where((h) => h.deletedAt.isNull());
    }
    return query.watch();
  }

  Future<List<Highlight>> getHighlightsForChapter(
    String bookId,
    int chapterIndex, {
    bool includeDeleted = false,
  }) {
    final query = select(highlights)
      ..where(
        (h) => h.bookId.equals(bookId) & h.chapterIndex.equals(chapterIndex),
      );
    if (!includeDeleted) {
      query.where((h) => h.deletedAt.isNull());
    }
    return query.get();
  }

  Future<int> insertHighlight(
    HighlightsCompanion highlight, {
    bool syncPending = true,
  }) => into(
    highlights,
  ).insert(highlight.copyWith(syncPending: Value(syncPending)));

  Future<bool> updateHighlight(
    HighlightsCompanion highlight, {
    bool syncPending = true,
  }) => update(
    highlights,
  ).replace(highlight.copyWith(syncPending: Value(syncPending)));

  Future<void> softDeleteHighlight(
    String id, {
    DateTime? deletedAt,
    bool markPending = true,
  }) async {
    final timestamp = deletedAt ?? DateTime.now();
    await (update(
      highlights,
    )..where((h) => h.id.equals(id) & h.deletedAt.isNull())).write(
      HighlightsCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
        syncPending: Value(markPending),
      ),
    );
  }

  // --- Collection queries ---
  Future<List<BookCollection>> getAllCollections({
    bool includeDeleted = false,
  }) {
    final query = select(bookCollections);
    if (!includeDeleted) {
      query.where((c) => c.deletedAt.isNull());
    }
    return query.get();
  }

  Stream<List<BookCollection>> watchAllCollections({
    bool includeDeleted = false,
  }) {
    final query = select(bookCollections);
    if (!includeDeleted) {
      query.where((c) => c.deletedAt.isNull());
    }
    return query.watch();
  }

  Future<BookCollection?> getCollectionById(
    String id, {
    bool includeDeleted = false,
  }) {
    final query = select(bookCollections)..where((c) => c.id.equals(id));
    if (!includeDeleted) {
      query.where((c) => c.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  Future<int> insertCollection(
    BookCollectionsCompanion collection, {
    bool syncPending = true,
  }) => into(
    bookCollections,
  ).insert(collection.copyWith(syncPending: Value(syncPending)));

  Future<bool> updateCollection(
    BookCollectionsCompanion collection, {
    bool syncPending = true,
  }) => update(
    bookCollections,
  ).replace(collection.copyWith(syncPending: Value(syncPending)));

  Future<void> softDeleteCollection(
    String id, {
    DateTime? deletedAt,
    bool markPending = true,
  }) async {
    final timestamp = deletedAt ?? DateTime.now();
    await transaction(() async {
      await (update(
        bookCollections,
      )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).write(
        BookCollectionsCompanion(
          deletedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          syncPending: Value(markPending),
        ),
      );
      await (update(collectionBooks)
            ..where((cb) => cb.collectionId.equals(id) & cb.deletedAt.isNull()))
          .write(
            CollectionBooksCompanion(
              deletedAt: Value(timestamp),
              updatedAt: Value(timestamp),
              syncPending: Value(markPending),
            ),
          );
    });
  }

  Future<List<Book>> getBooksInCollection(String collectionId) {
    final query = select(books).join([
      innerJoin(
        collectionBooks,
        collectionBooks.bookId.equalsExp(books.id) &
            collectionBooks.collectionId.equals(collectionId) &
            collectionBooks.deletedAt.isNull(),
      ),
    ]);
    query.where(books.deletedAt.isNull());
    query.orderBy([OrderingTerm.asc(collectionBooks.sortOrder)]);
    return query.map((row) => row.readTable(books)).get();
  }

  Stream<List<Book>> watchBooksInCollection(String collectionId) {
    final query = select(books).join([
      innerJoin(
        collectionBooks,
        collectionBooks.bookId.equalsExp(books.id) &
            collectionBooks.collectionId.equals(collectionId) &
            collectionBooks.deletedAt.isNull(),
      ),
    ]);
    query.where(books.deletedAt.isNull());
    query.orderBy([OrderingTerm.asc(collectionBooks.sortOrder)]);
    return query.map((row) => row.readTable(books)).watch();
  }

  Future<void> addBookToCollection(
    String collectionId,
    String bookId, {
    bool markPending = true,
  }) async {
    final now = DateTime.now();
    final existing =
        await (select(collectionBooks)..where(
              (cb) =>
                  cb.collectionId.equals(collectionId) &
                  cb.bookId.equals(bookId),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (update(collectionBooks)..where(
            (cb) =>
                cb.collectionId.equals(collectionId) & cb.bookId.equals(bookId),
          ))
          .write(
            CollectionBooksCompanion(
              updatedAt: Value(now),
              deletedAt: const Value(null),
              syncPending: Value(markPending),
            ),
          );
      return;
    }

    await into(collectionBooks).insert(
      CollectionBooksCompanion.insert(
        collectionId: collectionId,
        bookId: bookId,
        updatedAt: Value(now),
        syncPending: Value(markPending),
      ),
    );
  }

  Future<void> removeBookFromCollection(
    String collectionId,
    String bookId, {
    DateTime? deletedAt,
    bool markPending = true,
  }) async {
    final timestamp = deletedAt ?? DateTime.now();
    await (update(collectionBooks)..where(
          (cb) =>
              cb.collectionId.equals(collectionId) &
              cb.bookId.equals(bookId) &
              cb.deletedAt.isNull(),
        ))
        .write(
          CollectionBooksCompanion(
            deletedAt: Value(timestamp),
            updatedAt: Value(timestamp),
            syncPending: Value(markPending),
          ),
        );
  }

  // --- Reading session queries ---
  Future<List<ReadingSession>> getAllSessions({bool includeDeleted = false}) {
    final query = select(readingSessions);
    if (!includeDeleted) {
      query.where((s) => s.deletedAt.isNull());
    }
    query.orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    return query.get();
  }

  Future<List<ReadingSession>> getSessionsForBook(
    String bookId, {
    bool includeDeleted = false,
  }) {
    final query = select(readingSessions)
      ..where((s) => s.bookId.equals(bookId));
    if (!includeDeleted) {
      query.where((s) => s.deletedAt.isNull());
    }
    query.orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    return query.get();
  }

  Future<int> insertSession(
    ReadingSessionsCompanion session, {
    bool syncPending = true,
  }) => into(
    readingSessions,
  ).insert(session.copyWith(syncPending: Value(syncPending)));

  Future<bool> updateSession(
    ReadingSessionsCompanion session, {
    bool syncPending = true,
  }) => update(
    readingSessions,
  ).replace(session.copyWith(syncPending: Value(syncPending)));

  Future<void> softDeleteSession(
    String id, {
    DateTime? deletedAt,
    bool markPending = true,
  }) async {
    final timestamp = deletedAt ?? DateTime.now();
    await (update(
      readingSessions,
    )..where((s) => s.id.equals(id) & s.deletedAt.isNull())).write(
      ReadingSessionsCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
        syncPending: Value(markPending),
      ),
    );
  }

  // --- Reading goal queries ---
  Future<ReadingGoal?> getGoalForYear(int year, {bool includeDeleted = false}) {
    final query = select(readingGoals)..where((g) => g.year.equals(year));
    if (!includeDeleted) {
      query.where((g) => g.deletedAt.isNull());
    }
    return query.getSingleOrNull();
  }

  Future<List<ReadingGoal>> getAllGoals({bool includeDeleted = false}) {
    final query = select(readingGoals);
    if (!includeDeleted) {
      query.where((g) => g.deletedAt.isNull());
    }
    return query.get();
  }

  Future<int> upsertGoal(
    ReadingGoalsCompanion goal, {
    bool syncPending = true,
  }) => into(
    readingGoals,
  ).insertOnConflictUpdate(goal.copyWith(syncPending: Value(syncPending)));

  Future<void> softDeleteGoal(
    String id, {
    DateTime? deletedAt,
    bool markPending = true,
  }) async {
    final timestamp = deletedAt ?? DateTime.now();
    await (update(
      readingGoals,
    )..where((g) => g.id.equals(id) & g.deletedAt.isNull())).write(
      ReadingGoalsCompanion(
        deletedAt: Value(timestamp),
        updatedAt: Value(timestamp),
        syncPending: Value(markPending),
      ),
    );
  }

  // --- Collection book queries ---
  Future<List<CollectionBook>> getAllCollectionBooks({
    bool includeDeleted = false,
  }) {
    final query = select(collectionBooks);
    if (!includeDeleted) {
      query.where((cb) => cb.deletedAt.isNull());
    }
    return query.get();
  }

  /// Clears sync-scoped user content when switching to a different sync
  /// identity (server/account). Returns local file paths that should be
  /// cleaned up from disk after the DB transaction completes.
  Future<List<String>> clearAllSyncContent() async {
    final localAssetPaths = <String>{};
    final allBooks = await select(books).get();
    for (final book in allBooks) {
      if (book.filePath.isNotEmpty) {
        localAssetPaths.add(book.filePath);
      }
      if (book.coverPath case final coverPath? when coverPath.isNotEmpty) {
        localAssetPaths.add(coverPath);
      }
    }

    final collectionCovers = await select(bookCollections).get();
    for (final collection in collectionCovers) {
      if (collection.coverPath case final coverPath?
          when coverPath.isNotEmpty) {
        localAssetPaths.add(coverPath);
      }
    }

    await transaction(() async {
      await delete(collectionBooks).go();
      await delete(bookmarks).go();
      await delete(highlights).go();
      await delete(readingProgresses).go();
      await delete(readingSessions).go();
      await delete(readingGoals).go();
      await delete(bookCollections).go();
      await delete(books).go();
    });

    return localAssetPaths.toList(growable: false);
  }
}
