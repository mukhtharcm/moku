import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../database/database.dart';
import '../services/path_resolver.dart';

/// Syncs local Drift database with a remote PocketBase server.
/// Uses last-write-wins conflict resolution based on updatedAt timestamps.
class SyncEngine {
  final PocketBase pb;
  final AppDatabase db;

  DateTime? _lastSyncAt;

  SyncEngine({required this.pb, required this.db});

  DateTime? get lastSyncAt => _lastSyncAt;

  /// Sync all entity types. Returns the sync timestamp on success.
  Future<DateTime> syncAll({DateTime? lastSyncAt}) async {
    _lastSyncAt = lastSyncAt;
    final syncTime = DateTime.now().toUtc();

    await _syncBooks();
    await _syncReadingProgress();
    await _syncBookmarks();
    await _syncHighlights();
    await _syncCollections();
    await _syncCollectionBooks();

    return syncTime;
  }

  // ---------------------------------------------------------------------------
  // Books
  // ---------------------------------------------------------------------------

  Future<void> _syncBooks() async {
    await _pushBooks();
    await _pullBooks();
  }

  Future<void> _pushBooks() async {
    final record = pb.authStore.record;
    if (record == null) return;
    final userId = record.id;
    final allBooks = await db.getAllBooks();

    // Push new records (no remoteId)
    final newBooks =
        allBooks.where((b) => b.remoteId == null).toList();
    for (final book in newBooks) {
      try {
        final files = <http.MultipartFile>[];
        final resolvedFilePath = PathResolver.resolve(book.filePath);
        final epubFile = File(resolvedFilePath);
        if (await epubFile.exists()) {
          files.add(await http.MultipartFile.fromPath(
              'epub_file', resolvedFilePath));
        }
        if (book.coverPath != null) {
          final resolvedCoverPath = PathResolver.resolve(book.coverPath!);
          final coverFile = File(resolvedCoverPath);
          if (await coverFile.exists()) {
            files.add(await http.MultipartFile.fromPath(
                'cover_image', resolvedCoverPath));
          }
        }

        final record = await pb.collection('books').create(
          body: _bookToMap(book, userId),
          files: files,
        );

        await (db.update(db.books)
              ..where((b) => b.id.equals(book.id)))
            .write(BooksCompanion(remoteId: Value(record.id)));
      } catch (e) {
        // Skip this book on error, continue with others
      }
    }

    // Push updated records (have remoteId and updated after last sync)
    if (_lastSyncAt != null) {
      final updatedBooks = allBooks
          .where((b) =>
              b.remoteId != null && b.updatedAt.isAfter(_lastSyncAt!))
          .toList();
      for (final book in updatedBooks) {
        try {
          await pb.collection('books').update(
            book.remoteId!,
            body: _bookToMap(book, userId),
          );
        } catch (e) {
          // Skip on error
        }
      }
    }
  }

  Future<void> _pullBooks() async {
    final records = await _fetchRemoteRecords('books');

    for (final record in records) {
      final existingBook = await _findLocalBookByRemoteId(record.id);
      if (existingBook != null) {
        // Last-write-wins: only update if remote is newer
        final remoteUpdated = DateTime.parse(record.getStringValue('updated'));
        if (remoteUpdated.isAfter(existingBook.updatedAt)) {
          await (db.update(db.books)
                ..where((b) => b.id.equals(existingBook.id)))
              .write(_recordToBookCompanion(record, existingBook));
        }
      } else {
        // Check if we already have this book by file hash
        final fileHash = record.getStringValue('file_hash');
        Book? existingByHash;
        if (fileHash.isNotEmpty) {
          final matches = await (db.select(db.books)
                ..where((b) => b.fileHash.equals(fileHash)))
              .get();
          if (matches.isNotEmpty) existingByHash = matches.first;
        }

        if (existingByHash != null) {
          await (db.update(db.books)
                ..where((b) => b.id.equals(existingByHash!.id)))
              .write(BooksCompanion(remoteId: Value(record.id)));
        } else {
          // Download EPUB file and create local record
          await _downloadAndCreateBook(record);
        }
      }
    }
  }

  Future<void> _downloadAndCreateBook(RecordModel record) async {
    try {
      final epubFilename = record.getStringValue('epub_file');
      if (epubFilename.isEmpty) return;

      final epubUrl = pb.files.getUrl(record, epubFilename);
      final response = await http.get(epubUrl);
      if (response.statusCode != 200) return;

      // Save to app documents directory using moku_books structure
      final basePath = PathResolver.basePath;
      final absFilePath = '$basePath/moku_books/${record.id}_$epubFilename';
      final file = File(absFilePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);

      String? relCoverPath;
      final coverFilename = record.getStringValue('cover_image');
      if (coverFilename.isNotEmpty) {
        final coverUrl = pb.files.getUrl(record, coverFilename);
        final coverResp = await http.get(coverUrl);
        if (coverResp.statusCode == 200) {
          final absCoverPath = '$basePath/moku_books/covers/${record.id}_$coverFilename';
          final coverFile = File(absCoverPath);
          await coverFile.parent.create(recursive: true);
          await coverFile.writeAsBytes(coverResp.bodyBytes);
          relCoverPath = PathResolver.toRelative(absCoverPath);
        }
      }

      final now = DateTime.now();
      final publishDateStr = record.getStringValue('publish_date');
      await db.insertBook(BooksCompanion.insert(
        id: 'pb_${record.id.substring(0, 11)}',
        title: record.getStringValue('title'),
        author: record.getStringValue('author'),
        description: Value(record.getStringValue('description')),
        coverPath: Value(relCoverPath),
        filePath: PathResolver.toRelative(absFilePath),
        isbn: Value(record.getStringValue('isbn')),
        language: Value(record.getStringValue('language')),
        publisher: Value(record.getStringValue('publisher')),
        publishDate: Value(
          publishDateStr.isNotEmpty ? DateTime.tryParse(publishDateStr) : null,
        ),
        totalChapters: Value(record.getIntValue('total_chapters')),
        fileHash: Value(record.getStringValue('file_hash')),
        createdAt: now,
        updatedAt: now,
        remoteId: Value(record.id),
      ));
    } catch (e) {
      // Skip failed downloads
    }
  }

  // ---------------------------------------------------------------------------
  // Reading Progress
  // ---------------------------------------------------------------------------

  Future<void> _syncReadingProgress() async {
    await _pushReadingProgress();
    await _pullReadingProgress();
  }

  Future<void> _pushReadingProgress() async {
    final record = pb.authStore.record;
    if (record == null) return;
    final userId = record.id;
    final allProgress = await db.select(db.readingProgresses).get();

    for (final progress in allProgress) {
      final bookRemoteId = await _getBookRemoteId(progress.bookId);
      if (bookRemoteId == null) continue;

      if (progress.remoteId == null) {
        try {
          final record = await pb.collection('reading_progress').create(
            body: {
              'book': bookRemoteId,
              'user': userId,
              'current_chapter': progress.currentChapter,
              'chapter_progress': progress.chapterProgress,
              'overall_progress': progress.overallProgress,
              'last_position': progress.lastPosition ?? '',
              'last_read_at': progress.lastReadAt.toUtc().toIso8601String(),
            },
          );
          await (db.update(db.readingProgresses)
                ..where((p) => p.id.equals(progress.id)))
              .write(ReadingProgressesCompanion(
                  remoteId: Value(record.id)));
        } catch (e) {
          // Skip on error
        }
      } else if (_lastSyncAt != null &&
          progress.updatedAt.isAfter(_lastSyncAt!)) {
        try {
          await pb.collection('reading_progress').update(
            progress.remoteId!,
            body: {
              'current_chapter': progress.currentChapter,
              'chapter_progress': progress.chapterProgress,
              'overall_progress': progress.overallProgress,
              'last_position': progress.lastPosition ?? '',
              'last_read_at': progress.lastReadAt.toUtc().toIso8601String(),
            },
          );
        } catch (e) {
          // Skip on error
        }
      }
    }
  }

  Future<void> _pullReadingProgress() async {
    final records = await _fetchRemoteRecords('reading_progress');

    for (final record in records) {
      final localBookId =
          await _findLocalBookIdByRemoteId(record.getStringValue('book'));
      if (localBookId == null) continue;

      final existing = await (db.select(db.readingProgresses)
            ..where((p) => p.remoteId.equals(record.id)))
          .getSingleOrNull();

      final now = DateTime.now();
      if (existing != null) {
        final remoteUpdated = DateTime.parse(record.getStringValue('updated'));
        if (remoteUpdated.isAfter(existing.updatedAt)) {
          await (db.update(db.readingProgresses)
                ..where((p) => p.id.equals(existing.id)))
              .write(ReadingProgressesCompanion(
            currentChapter:
                Value(record.getIntValue('current_chapter')),
            chapterProgress:
                Value(record.getDoubleValue('chapter_progress')),
            overallProgress:
                Value(record.getDoubleValue('overall_progress')),
            lastPosition:
                Value(record.getStringValue('last_position')),
            lastReadAt: Value(
              DateTime.tryParse(
                      record.getStringValue('last_read_at')) ??
                  now,
            ),
            updatedAt: Value(now),
          ));
        }
      } else {
        await db.upsertProgress(ReadingProgressesCompanion.insert(
          id: 'rp_${record.id.substring(0, 11)}',
          bookId: localBookId,
          lastReadAt: DateTime.tryParse(
                  record.getStringValue('last_read_at')) ??
              now,
          updatedAt: now,
          currentChapter:
              Value(record.getIntValue('current_chapter')),
          chapterProgress:
              Value(record.getDoubleValue('chapter_progress')),
          overallProgress:
              Value(record.getDoubleValue('overall_progress')),
          lastPosition:
              Value(record.getStringValue('last_position')),
          remoteId: Value(record.id),
        ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  Future<void> _syncBookmarks() async {
    await _pushBookmarks();
    await _pullBookmarks();
  }

  Future<void> _pushBookmarks() async {
    final record = pb.authStore.record;
    if (record == null) return;
    final userId = record.id;
    final allBookmarks = await db.select(db.bookmarks).get();

    final newBookmarks =
        allBookmarks.where((b) => b.remoteId == null).toList();
    for (final bookmark in newBookmarks) {
      final bookRemoteId = await _getBookRemoteId(bookmark.bookId);
      if (bookRemoteId == null) continue;

      try {
        final record = await pb.collection('bookmarks').create(
          body: {
            'book': bookRemoteId,
            'user': userId,
            'chapter_index': bookmark.chapterIndex,
            'cfi': bookmark.cfi ?? '',
            'title': bookmark.title,
          },
        );
        await (db.update(db.bookmarks)
              ..where((b) => b.id.equals(bookmark.id)))
            .write(BookmarksCompanion(remoteId: Value(record.id)));
      } catch (e) {
        // Skip on error
      }
    }
  }

  Future<void> _pullBookmarks() async {
    final records = await _fetchRemoteRecords('bookmarks');

    for (final record in records) {
      final localBookId =
          await _findLocalBookIdByRemoteId(record.getStringValue('book'));
      if (localBookId == null) continue;

      final existing = await (db.select(db.bookmarks)
            ..where((b) => b.remoteId.equals(record.id)))
          .getSingleOrNull();

      if (existing == null) {
        await db.insertBookmark(BookmarksCompanion.insert(
          id: 'bm_${record.id.substring(0, 11)}',
          bookId: localBookId,
          chapterIndex: record.getIntValue('chapter_index'),
          title: record.getStringValue('title'),
          createdAt: DateTime.tryParse(record.getStringValue('created')) ?? DateTime.now(),
          cfi: Value(record.getStringValue('cfi')),
          remoteId: Value(record.id),
        ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Highlights
  // ---------------------------------------------------------------------------

  Future<void> _syncHighlights() async {
    await _pushHighlights();
    await _pullHighlights();
  }

  Future<void> _pushHighlights() async {
    final record = pb.authStore.record;
    if (record == null) return;
    final userId = record.id;
    final allHighlights = await db.select(db.highlights).get();

    final newHighlights =
        allHighlights.where((h) => h.remoteId == null).toList();
    for (final highlight in newHighlights) {
      final bookRemoteId = await _getBookRemoteId(highlight.bookId);
      if (bookRemoteId == null) continue;

      try {
        final record = await pb.collection('highlights').create(
          body: {
            'book': bookRemoteId,
            'user': userId,
            'chapter_index': highlight.chapterIndex,
            'start_cfi': highlight.startCfi ?? '',
            'end_cfi': highlight.endCfi ?? '',
            'selected_text': highlight.selectedText,
            'color': highlight.color,
            'note': highlight.note ?? '',
          },
        );
        await (db.update(db.highlights)
              ..where((h) => h.id.equals(highlight.id)))
            .write(HighlightsCompanion(remoteId: Value(record.id)));
      } catch (e) {
        // Skip on error
      }
    }

    // Push updated highlights
    if (_lastSyncAt != null) {
      final updated = allHighlights
          .where((h) =>
              h.remoteId != null && h.updatedAt.isAfter(_lastSyncAt!))
          .toList();
      for (final highlight in updated) {
        try {
          await pb.collection('highlights').update(
            highlight.remoteId!,
            body: {
              'selected_text': highlight.selectedText,
              'color': highlight.color,
              'note': highlight.note ?? '',
            },
          );
        } catch (e) {
          // Skip on error
        }
      }
    }
  }

  Future<void> _pullHighlights() async {
    final records = await _fetchRemoteRecords('highlights');

    for (final record in records) {
      final localBookId =
          await _findLocalBookIdByRemoteId(record.getStringValue('book'));
      if (localBookId == null) continue;

      final existing = await (db.select(db.highlights)
            ..where((h) => h.remoteId.equals(record.id)))
          .getSingleOrNull();

      final now = DateTime.now();
      if (existing != null) {
        final remoteUpdated = DateTime.parse(record.getStringValue('updated'));
        if (remoteUpdated.isAfter(existing.updatedAt)) {
          await (db.update(db.highlights)
                ..where((h) => h.id.equals(existing.id)))
              .write(HighlightsCompanion(
            selectedText:
                Value(record.getStringValue('selected_text')),
            color: Value(record.getStringValue('color')),
            note: Value(record.getStringValue('note')),
            updatedAt: Value(now),
          ));
        }
      } else {
        await db.insertHighlight(HighlightsCompanion.insert(
          id: 'hl_${record.id.substring(0, 11)}',
          bookId: localBookId,
          chapterIndex: record.getIntValue('chapter_index'),
          selectedText: record.getStringValue('selected_text'),
          createdAt: DateTime.tryParse(record.getStringValue('created')) ?? now,
          updatedAt: now,
          startCfi: Value(record.getStringValue('start_cfi')),
          endCfi: Value(record.getStringValue('end_cfi')),
          color: Value(record.getStringValue('color')),
          note: Value(record.getStringValue('note')),
          remoteId: Value(record.id),
        ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Collections (BookCollections)
  // ---------------------------------------------------------------------------

  Future<void> _syncCollections() async {
    await _pushCollections();
    await _pullCollections();
  }

  Future<void> _pushCollections() async {
    final record = pb.authStore.record;
    if (record == null) return;
    final userId = record.id;
    final allCollections = await db.getAllCollections();

    final newCollections =
        allCollections.where((c) => c.remoteId == null).toList();
    for (final collection in newCollections) {
      try {
        final record = await pb.collection('collections').create(
          body: {
            'name': collection.name,
            'description': collection.description ?? '',
            'user': userId,
          },
        );
        await (db.update(db.bookCollections)
              ..where((c) => c.id.equals(collection.id)))
            .write(BookCollectionsCompanion(
                remoteId: Value(record.id)));
      } catch (e) {
        // Skip on error
      }
    }

    // Push updated collections
    if (_lastSyncAt != null) {
      final updated = allCollections
          .where((c) =>
              c.remoteId != null && c.updatedAt.isAfter(_lastSyncAt!))
          .toList();
      for (final collection in updated) {
        try {
          await pb.collection('collections').update(
            collection.remoteId!,
            body: {
              'name': collection.name,
              'description': collection.description ?? '',
            },
          );
        } catch (e) {
          // Skip on error
        }
      }
    }
  }

  Future<void> _pullCollections() async {
    final records = await _fetchRemoteRecords('collections');

    for (final record in records) {
      final existing = await (db.select(db.bookCollections)
            ..where((c) => c.remoteId.equals(record.id)))
          .getSingleOrNull();

      final now = DateTime.now();
      if (existing != null) {
        final remoteUpdated = DateTime.parse(record.getStringValue('updated'));
        if (remoteUpdated.isAfter(existing.updatedAt)) {
          await (db.update(db.bookCollections)
                ..where((c) => c.id.equals(existing.id)))
              .write(BookCollectionsCompanion(
            name: Value(record.getStringValue('name')),
            description:
                Value(record.getStringValue('description')),
            updatedAt: Value(now),
          ));
        }
      } else {
        await db.insertCollection(BookCollectionsCompanion.insert(
          id: 'col_${record.id.substring(0, 10)}',
          name: record.getStringValue('name'),
          description:
              Value(record.getStringValue('description')),
          createdAt: DateTime.tryParse(record.getStringValue('created')) ?? now,
          updatedAt: now,
          remoteId: Value(record.id),
        ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CollectionBooks (junction table)
  // ---------------------------------------------------------------------------

  Future<void> _syncCollectionBooks() async {
    await _pushCollectionBooks();
    await _pullCollectionBooks();
  }

  Future<void> _pushCollectionBooks() async {
    // Get all local collection-book associations
    final allCollections = await db.getAllCollections();

    for (final collection in allCollections) {
      if (collection.remoteId == null) continue;

      final localBooks = await db.getBooksInCollection(collection.id);
      for (final book in localBooks) {
        if (book.remoteId == null) continue;

        // Check if this association already exists on server
        try {
          final existing = await pb.collection('collection_books').getFullList(
            filter:
                'collection = "${collection.remoteId}" && book = "${book.remoteId}"',
          );
          if (existing.isEmpty) {
            await pb.collection('collection_books').create(
              body: {
                'collection': collection.remoteId,
                'book': book.remoteId,
                'sort_order': 0,
              },
            );
          }
        } catch (e) {
          // Skip on error
        }
      }
    }
  }

  Future<void> _pullCollectionBooks() async {
    final records = await _fetchRemoteRecords('collection_books');

    for (final record in records) {
      final collectionRemoteId = record.getStringValue('collection');
      final bookRemoteId = record.getStringValue('book');

      final localCollectionId =
          await _findLocalCollectionIdByRemoteId(collectionRemoteId);
      final localBookId = await _findLocalBookIdByRemoteId(bookRemoteId);

      if (localCollectionId == null || localBookId == null) continue;

      // Check if association already exists locally
      try {
        final existingBooks =
            await db.getBooksInCollection(localCollectionId);
        final alreadyLinked =
            existingBooks.any((b) => b.id == localBookId);
        if (!alreadyLinked) {
          await db.addBookToCollection(localCollectionId, localBookId);
        }
      } catch (e) {
        // Skip on error
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<List<RecordModel>> _fetchRemoteRecords(String collection) async {
    try {
      if (_lastSyncAt != null) {
        final filter =
            'updated >= "${_lastSyncAt!.toUtc().toIso8601String()}"';
        return await pb.collection(collection).getFullList(filter: filter);
      }
      return await pb.collection(collection).getFullList();
    } catch (e) {
      return [];
    }
  }

  Future<Book?> _findLocalBookByRemoteId(String remoteId) async {
    return (db.select(db.books)
          ..where((b) => b.remoteId.equals(remoteId)))
        .getSingleOrNull();
  }

  Future<String?> _findLocalBookIdByRemoteId(String remoteId) async {
    final book = await _findLocalBookByRemoteId(remoteId);
    return book?.id;
  }

  Future<String?> _findLocalCollectionIdByRemoteId(
      String remoteId) async {
    final col = await (db.select(db.bookCollections)
          ..where((c) => c.remoteId.equals(remoteId)))
        .getSingleOrNull();
    return col?.id;
  }

  Future<String?> _getBookRemoteId(String localBookId) async {
    final book = await db.getBookById(localBookId);
    return book?.remoteId;
  }

  Map<String, dynamic> _bookToMap(Book book, String userId) {
    return {
      'title': book.title,
      'author': book.author,
      'description': book.description ?? '',
      'isbn': book.isbn ?? '',
      'language': book.language ?? '',
      'publisher': book.publisher ?? '',
      'publish_date': book.publishDate?.toUtc().toIso8601String() ?? '',
      'total_chapters': book.totalChapters,
      'file_hash': book.fileHash ?? '',
      'format': book.format,
      'user': userId,
    };
  }

  BooksCompanion _recordToBookCompanion(
      RecordModel record, Book existing) {
    final publishDateStr = record.getStringValue('publish_date');
    return BooksCompanion(
      title: Value(record.getStringValue('title')),
      author: Value(record.getStringValue('author')),
      description: Value(record.getStringValue('description')),
      isbn: Value(record.getStringValue('isbn')),
      language: Value(record.getStringValue('language')),
      publisher: Value(record.getStringValue('publisher')),
      publishDate: Value(
        publishDateStr.isNotEmpty ? DateTime.tryParse(publishDateStr) : null,
      ),
      totalChapters: Value(record.getIntValue('total_chapters')),
      fileHash: Value(record.getStringValue('file_hash')),
      format: Value(record.getStringValue('format').isNotEmpty
          ? record.getStringValue('format')
          : 'epub'),
      updatedAt: Value(DateTime.now()),
    );
  }

}
