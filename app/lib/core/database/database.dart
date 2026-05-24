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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Add 'format' column with default 'epub' for existing rows
        await customStatement(
          "ALTER TABLE books ADD COLUMN format TEXT NOT NULL DEFAULT 'epub'",
        );
      }
      if (from < 3) {
        await migrator.createTable(readingSessions);
        await migrator.createTable(readingGoals);
      }
      if (from < 4) {
        await migrator.addColumn(books, books.deletedAt);
        await migrator.addColumn(
          readingProgresses,
          readingProgresses.deletedAt,
        );
        await migrator.addColumn(bookmarks, bookmarks.updatedAt);
        await migrator.addColumn(bookmarks, bookmarks.deletedAt);
        await migrator.addColumn(highlights, highlights.deletedAt);
        await migrator.addColumn(bookCollections, bookCollections.deletedAt);
        await migrator.addColumn(collectionBooks, collectionBooks.remoteId);
        await migrator.addColumn(collectionBooks, collectionBooks.updatedAt);
        await migrator.addColumn(collectionBooks, collectionBooks.deletedAt);
      }
      if (from < 5) {
        await migrator.addColumn(readingSessions, readingSessions.updatedAt);
        await migrator.addColumn(readingSessions, readingSessions.deletedAt);
        await migrator.addColumn(readingGoals, readingGoals.updatedAt);
        await migrator.addColumn(readingGoals, readingGoals.deletedAt);
      }
      if (from < 6) {
        await migrator.addColumn(books, books.syncPending);
        await migrator.addColumn(
          readingProgresses,
          readingProgresses.syncPending,
        );
        await migrator.addColumn(bookmarks, bookmarks.syncPending);
        await migrator.addColumn(highlights, highlights.syncPending);
        await migrator.addColumn(bookCollections, bookCollections.syncPending);
        await migrator.addColumn(collectionBooks, collectionBooks.syncPending);
        await migrator.addColumn(readingSessions, readingSessions.syncPending);
        await migrator.addColumn(readingGoals, readingGoals.syncPending);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'moku_db');
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
}
