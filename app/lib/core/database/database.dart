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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'moku_db');
  }

  // --- Book queries ---
  Future<List<Book>> getAllBooks() => select(books).get();
  Stream<List<Book>> watchAllBooks() => select(books).watch();

  Future<Book?> getBookById(String id) =>
      (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<int> insertBook(BooksCompanion book) => into(books).insert(book);

  Future<bool> updateBook(BooksCompanion book) =>
      update(books).replace(book);

  Future<int> deleteBook(String id) =>
      (delete(books)..where((b) => b.id.equals(id))).go();

  // --- Reading progress queries ---
  Future<ReadingProgress?> getProgressForBook(String bookId) =>
      (select(readingProgresses)
            ..where((p) => p.bookId.equals(bookId)))
          .getSingleOrNull();

  Stream<ReadingProgress?> watchProgressForBook(String bookId) =>
      (select(readingProgresses)
            ..where((p) => p.bookId.equals(bookId)))
          .watchSingleOrNull();

  Future<int> upsertProgress(ReadingProgressesCompanion progress) =>
      into(readingProgresses).insertOnConflictUpdate(progress);

  // --- Bookmark queries ---
  Future<List<Bookmark>> getBookmarksForBook(String bookId) =>
      (select(bookmarks)
            ..where((b) => b.bookId.equals(bookId))
            ..orderBy([(b) => OrderingTerm.asc(b.chapterIndex)]))
          .get();

  Stream<List<Bookmark>> watchBookmarksForBook(String bookId) =>
      (select(bookmarks)
            ..where((b) => b.bookId.equals(bookId))
            ..orderBy([(b) => OrderingTerm.asc(b.chapterIndex)]))
          .watch();

  Future<int> insertBookmark(BookmarksCompanion bookmark) =>
      into(bookmarks).insert(bookmark);

  Future<int> deleteBookmark(String id) =>
      (delete(bookmarks)..where((b) => b.id.equals(id))).go();

  // --- Highlight queries ---
  Future<List<Highlight>> getHighlightsForBook(String bookId) =>
      (select(highlights)
            ..where((h) => h.bookId.equals(bookId))
            ..orderBy([(h) => OrderingTerm.asc(h.chapterIndex)]))
          .get();

  Stream<List<Highlight>> watchHighlightsForBook(String bookId) =>
      (select(highlights)
            ..where((h) => h.bookId.equals(bookId))
            ..orderBy([(h) => OrderingTerm.asc(h.chapterIndex)]))
          .watch();

  Future<List<Highlight>> getHighlightsForChapter(
    String bookId,
    int chapterIndex,
  ) =>
      (select(highlights)
            ..where(
              (h) =>
                  h.bookId.equals(bookId) &
                  h.chapterIndex.equals(chapterIndex),
            ))
          .get();

  Future<int> insertHighlight(HighlightsCompanion highlight) =>
      into(highlights).insert(highlight);

  Future<bool> updateHighlight(HighlightsCompanion highlight) =>
      update(highlights).replace(highlight);

  Future<int> deleteHighlight(String id) =>
      (delete(highlights)..where((h) => h.id.equals(id))).go();

  // --- Collection queries ---
  Future<List<BookCollection>> getAllCollections() =>
      select(bookCollections).get();

  Stream<List<BookCollection>> watchAllCollections() =>
      select(bookCollections).watch();

  Future<int> insertCollection(BookCollectionsCompanion collection) =>
      into(bookCollections).insert(collection);

  Future<bool> updateCollection(BookCollectionsCompanion collection) =>
      update(bookCollections).replace(collection);

  Future<int> deleteCollection(String id) =>
      (delete(bookCollections)..where((c) => c.id.equals(id))).go();

  Future<List<Book>> getBooksInCollection(String collectionId) {
    final query = select(books).join([
      innerJoin(
        collectionBooks,
        collectionBooks.bookId.equalsExp(books.id) &
            collectionBooks.collectionId.equals(collectionId),
      ),
    ]);
    query.orderBy([OrderingTerm.asc(collectionBooks.sortOrder)]);
    return query.map((row) => row.readTable(books)).get();
  }

  Stream<List<Book>> watchBooksInCollection(String collectionId) {
    final query = select(books).join([
      innerJoin(
        collectionBooks,
        collectionBooks.bookId.equalsExp(books.id) &
            collectionBooks.collectionId.equals(collectionId),
      ),
    ]);
    query.orderBy([OrderingTerm.asc(collectionBooks.sortOrder)]);
    return query.map((row) => row.readTable(books)).watch();
  }

  Future<int> addBookToCollection(String collectionId, String bookId) =>
      into(collectionBooks).insert(
        CollectionBooksCompanion.insert(
          collectionId: collectionId,
          bookId: bookId,
        ),
      );

  Future<int> removeBookFromCollection(
    String collectionId,
    String bookId,
  ) =>
      (delete(collectionBooks)
            ..where(
              (cb) =>
                  cb.collectionId.equals(collectionId) &
                  cb.bookId.equals(bookId),
            ))
          .go();
}
