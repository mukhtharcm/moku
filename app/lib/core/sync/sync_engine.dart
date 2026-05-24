import 'dart:developer';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../database/database.dart';
import '../services/path_resolver.dart';

/// Result of a sync run.
/// `syncedAt` is only set when ALL collections succeeded — partial successes
/// deliberately keep the old `lastSyncAt` cursor so failed entities will be
/// retried on the next run.
class SyncResult {
  /// Timestamp to advance `lastSyncAt` to. Null on any failure or if a sync
  /// was already in progress.
  final DateTime? syncedAt;

  /// Names of collections that failed. Empty on full success.
  final List<String> failedCollections;

  /// True if auth token was invalid/expired during the sync.
  final bool authFailed;

  /// True if another sync was already running and this call was skipped.
  final bool skippedAlreadyRunning;

  const SyncResult({
    this.syncedAt,
    this.failedCollections = const [],
    this.authFailed = false,
    this.skippedAlreadyRunning = false,
  });

  bool get isFullSuccess =>
      syncedAt != null && failedCollections.isEmpty && !authFailed;

  bool get hasFailures => failedCollections.isNotEmpty || authFailed;
}

/// Syncs local Drift database with a remote PocketBase server.
/// Uses last-write-wins conflict resolution based on updatedAt timestamps.
class SyncEngine {
  final PocketBase pb;
  final AppDatabase db;
  static const _noRemoteCursorField = '\u0000';
  // Pull cursors are based on the client's last successful sync time, not a
  // server-issued changelog token. Keep a small lookback so we don't miss
  // remote updates that land near the cursor boundary or on a skewed clock.
  static const _incrementalPullLookback = Duration(minutes: 5);
  static const _remoteCursorFieldCandidates = [
    'updated',
    'updated_at',
    'created',
    'created_at',
  ];

  DateTime? _lastSyncAt;
  DateTime? _syncStartedAt;
  bool _isSyncing = false;
  final Map<String, String> _remoteCursorFieldCache = {};
  final Set<String> _softFailedCollections = <String>{};

  /// Called when a sync stage fails with (collection, error).
  void Function(String collection, String error)? onError;

  SyncEngine({required this.pb, required this.db, this.onError});

  DateTime? get lastSyncAt => _lastSyncAt;

  bool get isSyncing => _isSyncing;

  static String normalizeBookFormatName(String? rawFormat, {String? filename}) {
    String? normalizeCandidate(String? value) {
      final candidate = value?.trim().toLowerCase();
      return switch (candidate) {
        'epub' => 'epub',
        'pdf' => 'pdf',
        'txt' || 'text' => 'txt',
        'cbz' => 'cbz',
        'html' || 'htm' || 'xhtml' => 'html',
        _ => null,
      };
    }

    final normalizedRaw = normalizeCandidate(rawFormat);
    if (normalizedRaw != null) return normalizedRaw;

    if (filename != null) {
      final dot = filename.lastIndexOf('.');
      if (dot >= 0 && dot < filename.length - 1) {
        final normalizedExtension = normalizeCandidate(
          filename.substring(dot + 1),
        );
        if (normalizedExtension != null) return normalizedExtension;
      }
    }

    return 'epub';
  }

  void _reportError(
    String collection,
    Object error,
    StackTrace? stackTrace, [
    List<String>? failed,
  ]) {
    final msg = error.toString();
    log(
      '$collection sync failed: $msg',
      name: 'SyncEngine',
      error: error,
      stackTrace: stackTrace,
    );
    final firstFailureThisRun = _softFailedCollections.add(collection);
    if (failed != null && !failed.contains(collection)) {
      failed.add(collection);
    }
    if (firstFailureThisRun) {
      onError?.call(collection, msg);
    }
  }

  /// Sync all entity types. Returns a [SyncResult] describing the outcome.
  /// Returns a result with `skippedAlreadyRunning: true` if a sync is in flight.
  Future<SyncResult> syncAll({DateTime? lastSyncAt}) async {
    if (_isSyncing) {
      log('Sync already in progress, skipping', name: 'SyncEngine');
      return const SyncResult(skippedAlreadyRunning: true);
    }
    _isSyncing = true;
    final failed = <String>[];
    bool authFailed = false;
    try {
      _lastSyncAt = lastSyncAt;
      final syncTime = DateTime.now().toUtc();
      _syncStartedAt = syncTime;
      _softFailedCollections.clear();

      // Refresh auth token before sync to avoid 401s
      try {
        await pb.collection('users').authRefresh();
      } catch (e) {
        log('Auth refresh failed: \$e', name: 'SyncEngine');
        // A failed refresh when token is no longer valid -> auth failure.
        if (!pb.authStore.isValid) {
          authFailed = true;
          return SyncResult(authFailed: true);
        }
      }

      try {
        await _syncBooks();
      } catch (e, st) {
        _reportError('books', e, st, failed);
      }
      try {
        await _syncReadingProgress();
      } catch (e, st) {
        _reportError('reading_progress', e, st, failed);
      }
      try {
        await _syncBookmarks();
      } catch (e, st) {
        _reportError('bookmarks', e, st, failed);
      }
      try {
        await _syncHighlights();
      } catch (e, st) {
        _reportError('highlights', e, st, failed);
      }
      try {
        await _syncCollections();
      } catch (e, st) {
        _reportError('collections', e, st, failed);
      }
      try {
        await _syncCollectionBooks();
      } catch (e, st) {
        _reportError('collection_books', e, st, failed);
      }
      try {
        await _syncReadingSessions();
      } catch (e, st) {
        _reportError('reading_sessions', e, st, failed);
      }
      try {
        await _syncReadingGoals();
      } catch (e, st) {
        _reportError('reading_goals', e, st, failed);
      }

      for (final collection in _softFailedCollections) {
        if (!failed.contains(collection)) {
          failed.add(collection);
        }
      }

      return SyncResult(
        // Only advance lastSyncAt on full success. Partial failures keep the
        // old cursor so the next run retries them.
        syncedAt: failed.isEmpty && !authFailed ? syncTime : null,
        failedCollections: List.unmodifiable(failed),
        authFailed: authFailed,
      );
    } finally {
      _syncStartedAt = null;
      _isSyncing = false;
      _softFailedCollections.clear();
    }
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
    final allBooks = await db.getAllBooks(includeDeleted: true);

    // Push new records (no remoteId)
    final newBooks = allBooks
        .where((b) => b.remoteId == null && b.deletedAt == null)
        .toList();
    for (final book in newBooks) {
      try {
        final record = await _createRemoteBook(book, userId);
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();

        await (db.update(db.books)..where((b) => b.id.equals(book.id))).write(
          BooksCompanion(
            remoteId: Value(record.id),
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('books', e, st);
      }
    }

    final updatedBooks = allBooks
        .where((b) => b.remoteId != null && b.syncPending)
        .toList();
    for (final book in updatedBooks) {
      try {
        final record = await pb
            .collection('books')
            .update(book.remoteId!, body: _bookToMap(book, userId));
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(db.books)..where((b) => b.id.equals(book.id))).write(
          BooksCompanion(
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('books', e, st);
      }
    }
  }

  Future<void> _pullBooks() async {
    final records = await _fetchRemoteRecords('books');

    for (final record in records) {
      final existingBook = await _findLocalBookByRemoteId(record.id);
      final remoteDeletedAt = _parseRemoteDeletedAt(record);
      if (existingBook != null) {
        if (remoteDeletedAt != null) {
          if (existingBook.deletedAt == null) {
            await db.softDeleteBook(
              existingBook.id,
              deletedAt: remoteDeletedAt,
              markPending: false,
            );
            await _deleteLocalBookFiles(existingBook);
          }
          continue;
        }
        if (existingBook.deletedAt != null) {
          continue;
        }
        final remoteUpdated = _parseRemoteTimestamp(record);
        final shouldApply = remoteUpdated != null
            ? remoteUpdated.isAfter(existingBook.updatedAt)
            : (!existingBook.syncPending &&
                  !_bookMatchesRecord(existingBook, record));
        if (shouldApply) {
          await (db.update(
            db.books,
          )..where((b) => b.id.equals(existingBook.id))).write(
            _recordToBookCompanion(
              record,
              existingBook,
              remoteUpdated ?? _fallbackRemoteTimestamp(),
            ),
          );
        }
      } else {
        // Check if we already have this book by file hash
        final fileHash = record.getStringValue('file_hash');
        Book? existingByHash;
        if (fileHash.isNotEmpty) {
          final matches = await (db.select(
            db.books,
          )..where((b) => b.fileHash.equals(fileHash))).get();
          if (matches.isNotEmpty) existingByHash = matches.first;
        }

        if (existingByHash != null) {
          if (existingByHash.deletedAt != null || remoteDeletedAt != null) {
            continue;
          }
          await (db.update(
            db.books,
          )..where((b) => b.id.equals(existingByHash!.id))).write(
            BooksCompanion(
              remoteId: Value(record.id),
              updatedAt: Value(
                _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp(),
              ),
              syncPending: const Value(false),
            ),
          );
        } else {
          if (remoteDeletedAt != null) continue;
          // Download EPUB file and create local record
          await _downloadAndCreateBook(record);
        }
      }
    }
  }

  Future<void> _downloadAndCreateBook(RecordModel record) async {
    try {
      final remoteFilename = _getRemoteBookFilename(record);
      if (remoteFilename.isEmpty) return;
      final remoteFormat = SyncEngine.normalizeBookFormatName(
        record.getStringValue('format'),
        filename: remoteFilename,
      );
      final resolvedFilename = remoteFilename;

      final fileUrl = pb.files.getUrl(record, resolvedFilename);
      final response = await http.get(fileUrl);
      if (response.statusCode != 200) return;

      // Save to app documents directory using moku_books structure
      final basePath = PathResolver.basePath;
      final absFilePath = '$basePath/moku_books/${record.id}_$resolvedFilename';
      final file = File(absFilePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);

      String? relCoverPath;
      final coverFilename = record.getStringValue('cover_image');
      if (coverFilename.isNotEmpty) {
        final coverUrl = pb.files.getUrl(record, coverFilename);
        final coverResp = await http.get(coverUrl);
        if (coverResp.statusCode == 200) {
          final absCoverPath =
              '$basePath/moku_books/covers/${record.id}_$coverFilename';
          final coverFile = File(absCoverPath);
          await coverFile.parent.create(recursive: true);
          await coverFile.writeAsBytes(coverResp.bodyBytes);
          relCoverPath = PathResolver.toRelative(absCoverPath);
        }
      }

      final remoteUpdated =
          _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
      final publishDateStr = record.getStringValue('publish_date');
      await db.insertBook(
        BooksCompanion.insert(
          id: 'pb_${record.id.substring(0, 11)}',
          title: record.getStringValue('title'),
          author: record.getStringValue('author'),
          description: Value(record.getStringValue('description')),
          coverPath: Value(relCoverPath),
          filePath: PathResolver.toRelative(absFilePath),
          format: Value(remoteFormat),
          isbn: Value(record.getStringValue('isbn')),
          language: Value(record.getStringValue('language')),
          publisher: Value(record.getStringValue('publisher')),
          publishDate: Value(
            publishDateStr.isNotEmpty
                ? DateTime.tryParse(publishDateStr)
                : null,
          ),
          totalChapters: Value(record.getIntValue('total_chapters')),
          fileHash: Value(record.getStringValue('file_hash')),
          createdAt: remoteUpdated,
          updatedAt: remoteUpdated,
          deletedAt: const Value(null),
          remoteId: Value(record.id),
        ),
        syncPending: false,
      );
    } catch (e, st) {
      _reportError('books', e, st);
    }
  }

  Future<RecordModel> _createRemoteBook(Book book, String userId) async {
    try {
      return await pb
          .collection('books')
          .create(
            body: _bookToMap(book, userId),
            files: await _buildRemoteBookFiles(
              book,
              primaryFileField: 'book_file',
            ),
          );
    } catch (e) {
      if (!_looksLikeLegacyBookFileSchemaError(e)) rethrow;
      return await pb
          .collection('books')
          .create(
            body: _bookToMap(book, userId),
            files: await _buildRemoteBookFiles(
              book,
              primaryFileField: 'epub_file',
            ),
          );
    }
  }

  Future<List<http.MultipartFile>> _buildRemoteBookFiles(
    Book book, {
    required String primaryFileField,
  }) async {
    final files = <http.MultipartFile>[];
    final resolvedFilePath = PathResolver.resolve(book.filePath);
    final bookFile = File(resolvedFilePath);
    if (await bookFile.exists()) {
      files.add(
        await http.MultipartFile.fromPath(primaryFileField, resolvedFilePath),
      );
    }
    if (book.coverPath != null) {
      final resolvedCoverPath = PathResolver.resolve(book.coverPath!);
      final coverFile = File(resolvedCoverPath);
      if (await coverFile.exists()) {
        files.add(
          await http.MultipartFile.fromPath('cover_image', resolvedCoverPath),
        );
      }
    }
    return files;
  }

  String _getRemoteBookFilename(RecordModel record) {
    final bookFile = record.getStringValue('book_file');
    if (bookFile.isNotEmpty) return bookFile;
    return record.getStringValue('epub_file');
  }

  bool _looksLikeLegacyBookFileSchemaError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('book_file') &&
        (message.contains('validation_unknown_field') ||
            message.contains('failed to create record'));
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

      if (progress.remoteId == null && progress.deletedAt == null) {
        try {
          final existingRemote = await _findRemoteRecordByFilter(
            'reading_progress',
            pb.filter('book = {:book} && user = {:user}', {
              'book': bookRemoteId,
              'user': userId,
            }),
          );
          if (existingRemote != null) {
            await _attachReadingProgressRemoteLink(progress, existingRemote);
            continue;
          }

          final record = await pb
              .collection('reading_progress')
              .create(
                body: {
                  'book': bookRemoteId,
                  'user': userId,
                  'current_chapter': progress.currentChapter,
                  'chapter_progress': progress.chapterProgress,
                  'overall_progress': progress.overallProgress,
                  'last_position': progress.lastPosition ?? '',
                  'last_read_at': progress.lastReadAt.toUtc().toIso8601String(),
                  'deleted_at': '',
                },
              );
          final remoteUpdated =
              _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
          await (db.update(
            db.readingProgresses,
          )..where((p) => p.id.equals(progress.id))).write(
            ReadingProgressesCompanion(
              remoteId: Value(record.id),
              updatedAt: Value(remoteUpdated),
              syncPending: const Value(false),
            ),
          );
        } catch (e, st) {
          _reportError('reading_progress', e, st);
        }
      } else if (progress.remoteId != null && progress.syncPending) {
        try {
          final record = await pb
              .collection('reading_progress')
              .update(
                progress.remoteId!,
                body: {
                  'current_chapter': progress.currentChapter,
                  'chapter_progress': progress.chapterProgress,
                  'overall_progress': progress.overallProgress,
                  'last_position': progress.lastPosition ?? '',
                  'last_read_at': progress.lastReadAt.toUtc().toIso8601String(),
                  'deleted_at':
                      progress.deletedAt?.toUtc().toIso8601String() ?? '',
                },
              );
          final remoteUpdated =
              _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
          await (db.update(
            db.readingProgresses,
          )..where((p) => p.id.equals(progress.id))).write(
            ReadingProgressesCompanion(
              updatedAt: Value(remoteUpdated),
              syncPending: const Value(false),
            ),
          );
        } catch (e, st) {
          _reportError('reading_progress', e, st);
        }
      }
    }
  }

  Future<void> _pullReadingProgress() async {
    final records = await _fetchRemoteRecords('reading_progress');

    for (final record in records) {
      final localBookId = await _findLocalBookIdByRemoteId(
        record.getStringValue('book'),
      );
      if (localBookId == null) continue;

      final existing =
          await (db.select(
            db.readingProgresses,
          )..where((p) => p.remoteId.equals(record.id))).getSingleOrNull() ??
          await db.getProgressForBook(localBookId, includeDeleted: true);

      final now = DateTime.now();
      final remoteUpdated = _parseRemoteTimestamp(record);
      final remoteDeletedAt = _parseRemoteDeletedAt(record);
      if (existing != null) {
        if (remoteDeletedAt != null) {
          if (existing.deletedAt == null || existing.remoteId == null) {
            await (db.update(
              db.readingProgresses,
            )..where((p) => p.id.equals(existing.id))).write(
              ReadingProgressesCompanion(
                remoteId: Value(record.id),
                deletedAt: Value(remoteDeletedAt),
                updatedAt: Value(remoteDeletedAt),
                syncPending: const Value(false),
              ),
            );
          }
          continue;
        }
        if (existing.deletedAt != null) {
          if (existing.syncPending && existing.remoteId == null) {
            await (db.update(db.readingProgresses)
                  ..where((p) => p.id.equals(existing.id)))
                .write(ReadingProgressesCompanion(remoteId: Value(record.id)));
          }
          continue;
        }
        final shouldApply = remoteUpdated != null
            ? remoteUpdated.isAfter(existing.updatedAt)
            : (!existing.syncPending &&
                  !_readingProgressMatchesRecord(existing, record));
        if (shouldApply) {
          await (db.update(
            db.readingProgresses,
          )..where((p) => p.id.equals(existing.id))).write(
            ReadingProgressesCompanion(
              remoteId: Value(record.id),
              currentChapter: Value(record.getIntValue('current_chapter')),
              chapterProgress: Value(record.getDoubleValue('chapter_progress')),
              overallProgress: Value(record.getDoubleValue('overall_progress')),
              lastPosition: Value(record.getStringValue('last_position')),
              lastReadAt: Value(
                DateTime.tryParse(record.getStringValue('last_read_at')) ?? now,
              ),
              updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
              deletedAt: const Value(null),
              syncPending: const Value(false),
            ),
          );
        } else if (existing.remoteId == null) {
          await (db.update(db.readingProgresses)
                ..where((p) => p.id.equals(existing.id)))
              .write(ReadingProgressesCompanion(remoteId: Value(record.id)));
        }
      } else {
        if (remoteDeletedAt != null) continue;
        await db.upsertProgress(
          ReadingProgressesCompanion.insert(
            id: 'rp_${record.id.substring(0, 11)}',
            bookId: localBookId,
            lastReadAt:
                DateTime.tryParse(record.getStringValue('last_read_at')) ?? now,
            updatedAt: remoteUpdated ?? _fallbackRemoteTimestamp(),
            currentChapter: Value(record.getIntValue('current_chapter')),
            chapterProgress: Value(record.getDoubleValue('chapter_progress')),
            overallProgress: Value(record.getDoubleValue('overall_progress')),
            lastPosition: Value(record.getStringValue('last_position')),
            deletedAt: const Value(null),
            remoteId: Value(record.id),
          ),
          syncPending: false,
        );
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

    final newBookmarks = allBookmarks
        .where((b) => b.remoteId == null && b.deletedAt == null)
        .toList();
    for (final bookmark in newBookmarks) {
      final bookRemoteId = await _getBookRemoteId(bookmark.bookId);
      if (bookRemoteId == null) continue;

      try {
        final record = await pb
            .collection('bookmarks')
            .create(
              body: {
                'book': bookRemoteId,
                'user': userId,
                'chapter_index': bookmark.chapterIndex,
                'cfi': bookmark.cfi ?? '',
                'title': bookmark.title,
                'deleted_at': '',
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.bookmarks,
        )..where((b) => b.id.equals(bookmark.id))).write(
          BookmarksCompanion(
            remoteId: Value(record.id),
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('bookmarks', e, st);
      }
    }

    final updatedBookmarks = allBookmarks
        .where((b) => b.remoteId != null && b.syncPending)
        .toList();
    for (final bookmark in updatedBookmarks) {
      try {
        final record = await pb
            .collection('bookmarks')
            .update(
              bookmark.remoteId!,
              body: {
                'chapter_index': bookmark.chapterIndex,
                'cfi': bookmark.cfi ?? '',
                'title': bookmark.title,
                'deleted_at':
                    bookmark.deletedAt?.toUtc().toIso8601String() ?? '',
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.bookmarks,
        )..where((b) => b.id.equals(bookmark.id))).write(
          BookmarksCompanion(
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('bookmarks', e, st);
      }
    }
  }

  Future<void> _pullBookmarks() async {
    final records = await _fetchRemoteRecords('bookmarks');

    for (final record in records) {
      final localBookId = await _findLocalBookIdByRemoteId(
        record.getStringValue('book'),
      );
      if (localBookId == null) continue;

      final existing = await (db.select(
        db.bookmarks,
      )..where((b) => b.remoteId.equals(record.id))).getSingleOrNull();

      final remoteDeletedAt = _parseRemoteDeletedAt(record);
      final remoteUpdated = _parseRemoteTimestamp(record);

      if (existing != null) {
        if (remoteDeletedAt != null) {
          if (existing.deletedAt == null) {
            await db.softDeleteBookmark(
              existing.id,
              deletedAt: remoteDeletedAt,
              markPending: false,
            );
          }
          continue;
        }
        if (existing.deletedAt != null) {
          continue;
        }
        final shouldApply = remoteUpdated != null
            ? remoteUpdated.isAfter(existing.updatedAt)
            : (!existing.syncPending &&
                  !_bookmarkMatchesRecord(existing, record));
        if (!shouldApply) continue;
        await (db.update(
          db.bookmarks,
        )..where((b) => b.id.equals(existing.id))).write(
          BookmarksCompanion(
            chapterIndex: Value(record.getIntValue('chapter_index')),
            cfi: Value(record.getStringValue('cfi')),
            title: Value(record.getStringValue('title')),
            updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
            deletedAt: const Value(null),
            syncPending: const Value(false),
          ),
        );
        continue;
      }

      if (remoteDeletedAt == null) {
        await db.insertBookmark(
          BookmarksCompanion.insert(
            id: 'bm_${record.id.substring(0, 11)}',
            bookId: localBookId,
            chapterIndex: record.getIntValue('chapter_index'),
            title: record.getStringValue('title'),
            createdAt:
                _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp(),
            updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
            cfi: Value(record.getStringValue('cfi')),
            deletedAt: const Value(null),
            remoteId: Value(record.id),
          ),
          syncPending: false,
        );
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

    final newHighlights = allHighlights
        .where((h) => h.remoteId == null && h.deletedAt == null)
        .toList();
    for (final highlight in newHighlights) {
      final bookRemoteId = await _getBookRemoteId(highlight.bookId);
      if (bookRemoteId == null) continue;

      try {
        final record = await pb
            .collection('highlights')
            .create(
              body: {
                'book': bookRemoteId,
                'user': userId,
                'chapter_index': highlight.chapterIndex,
                'start_cfi': highlight.startCfi ?? '',
                'end_cfi': highlight.endCfi ?? '',
                'selected_text': highlight.selectedText,
                'color': highlight.color,
                'note': highlight.note ?? '',
                'deleted_at': '',
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.highlights,
        )..where((h) => h.id.equals(highlight.id))).write(
          HighlightsCompanion(
            remoteId: Value(record.id),
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('highlights', e, st);
      }
    }

    final updated = allHighlights
        .where((h) => h.remoteId != null && h.syncPending)
        .toList();
    for (final highlight in updated) {
      try {
        final record = await pb
            .collection('highlights')
            .update(
              highlight.remoteId!,
              body: {
                'selected_text': highlight.selectedText,
                'color': highlight.color,
                'note': highlight.note ?? '',
                'deleted_at':
                    highlight.deletedAt?.toUtc().toIso8601String() ?? '',
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.highlights,
        )..where((h) => h.id.equals(highlight.id))).write(
          HighlightsCompanion(
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('highlights', e, st);
      }
    }
  }

  Future<void> _pullHighlights() async {
    final records = await _fetchRemoteRecords('highlights');

    for (final record in records) {
      final localBookId = await _findLocalBookIdByRemoteId(
        record.getStringValue('book'),
      );
      if (localBookId == null) continue;

      final existing = await (db.select(
        db.highlights,
      )..where((h) => h.remoteId.equals(record.id))).getSingleOrNull();

      final remoteUpdated = _parseRemoteTimestamp(record);
      final remoteDeletedAt = _parseRemoteDeletedAt(record);
      if (existing != null) {
        if (remoteDeletedAt != null) {
          if (existing.deletedAt == null) {
            await db.softDeleteHighlight(
              existing.id,
              deletedAt: remoteDeletedAt,
              markPending: false,
            );
          }
          continue;
        }
        if (existing.deletedAt != null) {
          continue;
        }
        final shouldApply = remoteUpdated != null
            ? remoteUpdated.isAfter(existing.updatedAt)
            : (!existing.syncPending &&
                  !_highlightMatchesRecord(existing, record));
        if (shouldApply) {
          await (db.update(
            db.highlights,
          )..where((h) => h.id.equals(existing.id))).write(
            HighlightsCompanion(
              selectedText: Value(record.getStringValue('selected_text')),
              color: Value(record.getStringValue('color')),
              note: Value(record.getStringValue('note')),
              updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
              deletedAt: const Value(null),
              syncPending: const Value(false),
            ),
          );
        }
      } else {
        if (remoteDeletedAt != null) continue;
        final resolvedTimestamp = remoteUpdated ?? _fallbackRemoteTimestamp();
        await db.insertHighlight(
          HighlightsCompanion.insert(
            id: 'hl_${record.id.substring(0, 11)}',
            bookId: localBookId,
            chapterIndex: record.getIntValue('chapter_index'),
            selectedText: record.getStringValue('selected_text'),
            createdAt: resolvedTimestamp,
            updatedAt: resolvedTimestamp,
            startCfi: Value(record.getStringValue('start_cfi')),
            endCfi: Value(record.getStringValue('end_cfi')),
            color: Value(record.getStringValue('color')),
            note: Value(record.getStringValue('note')),
            deletedAt: const Value(null),
            remoteId: Value(record.id),
          ),
          syncPending: false,
        );
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
    final allCollections = await db.getAllCollections(includeDeleted: true);

    final newCollections = allCollections
        .where((c) => c.remoteId == null && c.deletedAt == null)
        .toList();
    for (final collection in newCollections) {
      try {
        final record = await pb
            .collection('collections')
            .create(
              body: {
                'name': collection.name,
                'description': collection.description ?? '',
                'deleted_at': '',
                'user': userId,
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.bookCollections,
        )..where((c) => c.id.equals(collection.id))).write(
          BookCollectionsCompanion(
            remoteId: Value(record.id),
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('collections', e, st);
      }
    }

    final updated = allCollections
        .where((c) => c.remoteId != null && c.syncPending)
        .toList();
    for (final collection in updated) {
      try {
        final record = await pb
            .collection('collections')
            .update(
              collection.remoteId!,
              body: {
                'name': collection.name,
                'description': collection.description ?? '',
                'deleted_at':
                    collection.deletedAt?.toUtc().toIso8601String() ?? '',
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.bookCollections,
        )..where((c) => c.id.equals(collection.id))).write(
          BookCollectionsCompanion(
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('collections', e, st);
      }
    }
  }

  Future<void> _pullCollections() async {
    final records = await _fetchRemoteRecords('collections');

    for (final record in records) {
      final existing = await (db.select(
        db.bookCollections,
      )..where((c) => c.remoteId.equals(record.id))).getSingleOrNull();

      final remoteUpdated = _parseRemoteTimestamp(record);
      final remoteDeletedAt = _parseRemoteDeletedAt(record);
      if (existing != null) {
        if (remoteDeletedAt != null) {
          if (existing.deletedAt == null) {
            await db.softDeleteCollection(
              existing.id,
              deletedAt: remoteDeletedAt,
              markPending: false,
            );
          }
          continue;
        }
        if (existing.deletedAt != null) {
          continue;
        }
        final shouldApply = remoteUpdated != null
            ? remoteUpdated.isAfter(existing.updatedAt)
            : (!existing.syncPending &&
                  !_collectionMatchesRecord(existing, record));
        if (shouldApply) {
          await (db.update(
            db.bookCollections,
          )..where((c) => c.id.equals(existing.id))).write(
            BookCollectionsCompanion(
              name: Value(record.getStringValue('name')),
              description: Value(record.getStringValue('description')),
              updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
              deletedAt: const Value(null),
              syncPending: const Value(false),
            ),
          );
        }
      } else {
        if (remoteDeletedAt != null) continue;
        final resolvedTimestamp = remoteUpdated ?? _fallbackRemoteTimestamp();
        await db.insertCollection(
          BookCollectionsCompanion.insert(
            id: 'col_${record.id.substring(0, 10)}',
            name: record.getStringValue('name'),
            description: Value(record.getStringValue('description')),
            createdAt: resolvedTimestamp,
            updatedAt: resolvedTimestamp,
            deletedAt: const Value(null),
            remoteId: Value(record.id),
          ),
          syncPending: false,
        );
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
    final allAssociations = await db.getAllCollectionBooks(
      includeDeleted: true,
    );

    for (final assoc in allAssociations) {
      final collection = await (db.select(
        db.bookCollections,
      )..where((c) => c.id.equals(assoc.collectionId))).getSingleOrNull();
      final book = await db.getBookById(assoc.bookId, includeDeleted: true);
      if (collection?.remoteId == null || book?.remoteId == null) continue;

      try {
        if (assoc.remoteId == null) {
          final existing = await pb
              .collection('collection_books')
              .getFullList(
                filter:
                    'collection = "${collection!.remoteId}" && book = "${book!.remoteId}"',
              );
          if (existing.isEmpty) {
            if (assoc.deletedAt != null) {
              continue;
            }
            final created = await pb
                .collection('collection_books')
                .create(
                  body: {
                    'collection': collection.remoteId,
                    'book': book.remoteId,
                    'sort_order': assoc.sortOrder,
                    'deleted_at': '',
                  },
                );
            final remoteUpdated =
                _parseRemoteTimestamp(created) ?? _fallbackRemoteTimestamp();
            await (db.update(db.collectionBooks)..where(
                  (cb) =>
                      cb.collectionId.equals(assoc.collectionId) &
                      cb.bookId.equals(assoc.bookId),
                ))
                .write(
                  CollectionBooksCompanion(
                    remoteId: Value(created.id),
                    updatedAt: Value(remoteUpdated),
                    syncPending: const Value(false),
                  ),
                );
            continue;
          }

          final remote = existing.first;
          await (db.update(db.collectionBooks)..where(
                (cb) =>
                    cb.collectionId.equals(assoc.collectionId) &
                    cb.bookId.equals(assoc.bookId),
              ))
              .write(
                CollectionBooksCompanion(
                  remoteId: Value(remote.id),
                  updatedAt: Value(
                    _parseRemoteTimestamp(remote) ?? _fallbackRemoteTimestamp(),
                  ),
                ),
              );

          final updatedRecord = await pb
              .collection('collection_books')
              .update(
                remote.id,
                body: {
                  'sort_order': assoc.sortOrder,
                  'deleted_at':
                      assoc.deletedAt?.toUtc().toIso8601String() ?? '',
                },
              );
          final remoteUpdated =
              _parseRemoteTimestamp(updatedRecord) ??
              _fallbackRemoteTimestamp();
          await (db.update(db.collectionBooks)..where(
                (cb) =>
                    cb.collectionId.equals(assoc.collectionId) &
                    cb.bookId.equals(assoc.bookId),
              ))
              .write(
                CollectionBooksCompanion(
                  updatedAt: Value(remoteUpdated),
                  syncPending: const Value(false),
                ),
              );
          continue;
        }

        if (assoc.syncPending) {
          final updatedRecord = await pb
              .collection('collection_books')
              .update(
                assoc.remoteId!,
                body: {
                  'sort_order': assoc.sortOrder,
                  'deleted_at':
                      assoc.deletedAt?.toUtc().toIso8601String() ?? '',
                },
              );
          final remoteUpdated =
              _parseRemoteTimestamp(updatedRecord) ??
              _fallbackRemoteTimestamp();
          await (db.update(db.collectionBooks)..where(
                (cb) =>
                    cb.collectionId.equals(assoc.collectionId) &
                    cb.bookId.equals(assoc.bookId),
              ))
              .write(
                CollectionBooksCompanion(
                  updatedAt: Value(remoteUpdated),
                  syncPending: const Value(false),
                ),
              );
        }
      } catch (e) {
        _reportError('collection_books', e, null);
      }
    }
  }

  Future<void> _pullCollectionBooks() async {
    final records = await _fetchRemoteRecords('collection_books');

    for (final record in records) {
      final collectionRemoteId = record.getStringValue('collection');
      final bookRemoteId = record.getStringValue('book');

      final localCollectionId = await _findLocalCollectionIdByRemoteId(
        collectionRemoteId,
      );
      final localBookId = await _findLocalBookIdByRemoteId(bookRemoteId);

      if (localCollectionId == null || localBookId == null) continue;

      try {
        final existing =
            await _findLocalCollectionBookByRemoteId(record.id) ??
            await (db.select(db.collectionBooks)..where(
                  (cb) =>
                      cb.collectionId.equals(localCollectionId) &
                      cb.bookId.equals(localBookId),
                ))
                .getSingleOrNull();
        final remoteDeletedAt = _parseRemoteDeletedAt(record);
        final remoteUpdated = _parseRemoteTimestamp(record);

        if (existing != null) {
          if (remoteDeletedAt != null) {
            if (existing.deletedAt == null) {
              await db.removeBookFromCollection(
                localCollectionId,
                localBookId,
                deletedAt: remoteDeletedAt,
                markPending: false,
              );
            }
            if (existing.remoteId == null) {
              await (db.update(db.collectionBooks)..where(
                    (cb) =>
                        cb.collectionId.equals(localCollectionId) &
                        cb.bookId.equals(localBookId),
                  ))
                  .write(
                    CollectionBooksCompanion(
                      remoteId: Value(record.id),
                      updatedAt: Value(
                        remoteUpdated ?? _fallbackRemoteTimestamp(),
                      ),
                      syncPending: const Value(false),
                    ),
                  );
            }
            continue;
          }

          final remoteSort = record.getIntValue('sort_order');
          if (existing.deletedAt != null) {
            if (existing.syncPending) {
              if (existing.remoteId == null) {
                await (db.update(db.collectionBooks)..where(
                      (cb) =>
                          cb.collectionId.equals(localCollectionId) &
                          cb.bookId.equals(localBookId),
                    ))
                    .write(
                      CollectionBooksCompanion(
                        remoteId: Value(record.id),
                        updatedAt: Value(
                          remoteUpdated ?? _fallbackRemoteTimestamp(),
                        ),
                      ),
                    );
              }
              continue;
            }

            await (db.update(db.collectionBooks)..where(
                  (cb) =>
                      cb.collectionId.equals(localCollectionId) &
                      cb.bookId.equals(localBookId),
                ))
                .write(
                  CollectionBooksCompanion(
                    remoteId: Value(record.id),
                    sortOrder: Value(remoteSort),
                    updatedAt: Value(
                      remoteUpdated ?? _fallbackRemoteTimestamp(),
                    ),
                    deletedAt: const Value(null),
                    syncPending: const Value(false),
                  ),
                );
            continue;
          }

          if (existing.sortOrder != remoteSort || existing.remoteId == null) {
            await (db.update(db.collectionBooks)..where(
                  (cb) =>
                      cb.collectionId.equals(localCollectionId) &
                      cb.bookId.equals(localBookId),
                ))
                .write(
                  CollectionBooksCompanion(
                    remoteId: Value(record.id),
                    sortOrder: Value(remoteSort),
                    updatedAt: Value(
                      remoteUpdated ?? _fallbackRemoteTimestamp(),
                    ),
                    deletedAt: const Value(null),
                    syncPending: const Value(false),
                  ),
                );
          }
          continue;
        }

        if (remoteDeletedAt == null) {
          await db
              .into(db.collectionBooks)
              .insert(
                CollectionBooksCompanion.insert(
                  collectionId: localCollectionId,
                  bookId: localBookId,
                  sortOrder: Value(record.getIntValue('sort_order')),
                  remoteId: Value(record.id),
                  updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
                  syncPending: const Value(false),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      } catch (e) {
        _reportError('collection_books', e, null);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reading Sessions
  // ---------------------------------------------------------------------------

  Future<void> _syncReadingSessions() async {
    await _pushReadingSessions();
    await _pullReadingSessions();
  }

  Future<void> _pushReadingSessions() async {
    final record = pb.authStore.record;
    if (record == null) return;
    final userId = record.id;
    final sessions = await db.getAllSessions(includeDeleted: true);

    for (final session in sessions.where(
      (s) => s.remoteId == null && s.deletedAt == null,
    )) {
      final bookRemoteId = await _getBookRemoteId(session.bookId);
      if (bookRemoteId == null) continue;

      try {
        final existingRemote = await _findRemoteRecordByFilter(
          'reading_sessions',
          pb.filter(
            'book = {:book} && user = {:user} && started_at = {:start}',
            {
              'book': bookRemoteId,
              'user': userId,
              'start': session.startedAt.toUtc(),
            },
          ),
        );
        if (existingRemote != null) {
          await _attachReadingSessionRemoteLink(session, existingRemote);
          continue;
        }

        final body = <String, dynamic>{
          'book': bookRemoteId,
          'user': userId,
          'book_title': session.bookTitle,
          'started_at': session.startedAt.toUtc().toIso8601String(),
          'duration_seconds': session.durationSeconds,
          'start_chapter': session.startChapter,
          'end_chapter': session.endChapter,
          'deleted_at': '',
        };
        if (session.endedAt != null) {
          body['ended_at'] = session.endedAt!.toUtc().toIso8601String();
        }
        final remoteRecord = await pb
            .collection('reading_sessions')
            .create(body: body);
        final remoteUpdated =
            _parseRemoteTimestamp(remoteRecord) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.readingSessions,
        )..where((s) => s.id.equals(session.id))).write(
          ReadingSessionsCompanion(
            remoteId: Value(remoteRecord.id),
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('reading_sessions', e, st);
      }
    }

    final updatedSessions = sessions
        .where((s) => s.remoteId != null && s.syncPending)
        .toList();
    for (final session in updatedSessions) {
      try {
        final body = <String, dynamic>{
          'book_title': session.bookTitle,
          'duration_seconds': session.durationSeconds,
          'start_chapter': session.startChapter,
          'end_chapter': session.endChapter,
          'deleted_at': session.deletedAt?.toUtc().toIso8601String() ?? '',
        };
        if (session.endedAt != null) {
          body['ended_at'] = session.endedAt!.toUtc().toIso8601String();
        }
        final record = await pb
            .collection('reading_sessions')
            .update(session.remoteId!, body: body);
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.readingSessions,
        )..where((s) => s.id.equals(session.id))).write(
          ReadingSessionsCompanion(
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('reading_sessions', e, st);
      }
    }
  }

  Future<void> _pullReadingSessions() async {
    final records = await _fetchRemoteRecords('reading_sessions');
    for (final record in records) {
      final localBookId = await _findLocalBookIdByRemoteId(
        record.getStringValue('book'),
      );
      if (localBookId == null) continue;

      final startedAt =
          DateTime.tryParse(record.getStringValue('started_at')) ??
          DateTime.now();
      final windowStart = startedAt.subtract(const Duration(seconds: 60));
      final windowEnd = startedAt.add(const Duration(seconds: 60));

      final existing =
          await (db.select(
            db.readingSessions,
          )..where((s) => s.remoteId.equals(record.id))).getSingleOrNull() ??
          await (db.select(db.readingSessions)..where(
                (s) =>
                    s.bookId.equals(localBookId) &
                    s.startedAt.isBetweenValues(windowStart, windowEnd),
              ))
              .getSingleOrNull();
      final remoteDeletedAt = _parseRemoteDeletedAt(record);
      final remoteUpdated = _parseRemoteTimestamp(record);

      if (existing != null) {
        if (remoteDeletedAt != null) {
          if (existing.deletedAt == null || existing.remoteId == null) {
            await (db.update(
              db.readingSessions,
            )..where((s) => s.id.equals(existing.id))).write(
              ReadingSessionsCompanion(
                remoteId: Value(record.id),
                deletedAt: Value(remoteDeletedAt),
                updatedAt: Value(remoteDeletedAt),
                syncPending: const Value(false),
              ),
            );
          }
          continue;
        }

        if (existing.deletedAt != null) {
          if (existing.syncPending) {
            if (existing.remoteId == null) {
              await (db.update(db.readingSessions)
                    ..where((s) => s.id.equals(existing.id)))
                  .write(ReadingSessionsCompanion(remoteId: Value(record.id)));
            }
            continue;
          }
          if (existing.remoteId == null) {
            await (db.update(db.readingSessions)
                  ..where((s) => s.id.equals(existing.id)))
                .write(ReadingSessionsCompanion(remoteId: Value(record.id)));
          }
          continue;
        }

        final shouldApply = remoteUpdated != null
            ? remoteUpdated.isAfter(existing.updatedAt)
            : existing.bookTitle != record.getStringValue('book_title') ||
                  existing.durationSeconds !=
                      record.getIntValue('duration_seconds') ||
                  existing.startChapter !=
                      record.getIntValue('start_chapter') ||
                  existing.endChapter != record.getIntValue('end_chapter') ||
                  existing.endedAt?.toUtc() !=
                      DateTime.tryParse(
                        record.getStringValue('ended_at'),
                      )?.toUtc() ||
                  existing.deletedAt != null;
        if (!shouldApply) {
          if (existing.remoteId == null) {
            await (db.update(db.readingSessions)
                  ..where((s) => s.id.equals(existing.id)))
                .write(ReadingSessionsCompanion(remoteId: Value(record.id)));
          }
          continue;
        }

        final endedAtStr = record.getStringValue('ended_at');
        final endedAt = endedAtStr.isNotEmpty
            ? DateTime.tryParse(endedAtStr)
            : null;
        await (db.update(
          db.readingSessions,
        )..where((s) => s.id.equals(existing.id))).write(
          ReadingSessionsCompanion(
            remoteId: Value(record.id),
            bookTitle: Value(record.getStringValue('book_title')),
            endedAt: Value(endedAt),
            durationSeconds: Value(record.getIntValue('duration_seconds')),
            startChapter: Value(record.getIntValue('start_chapter')),
            endChapter: Value(record.getIntValue('end_chapter')),
            updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
            deletedAt: const Value(null),
            syncPending: const Value(false),
          ),
        );
        continue;
      }

      if (remoteDeletedAt != null) continue;

      final book = await db.getBookById(localBookId);
      final endedAtStr = record.getStringValue('ended_at');
      final endedAt = endedAtStr.isNotEmpty
          ? DateTime.tryParse(endedAtStr)
          : null;

      await db.insertSession(
        ReadingSessionsCompanion.insert(
          id: 'rs_${record.id.substring(0, 11)}',
          bookId: localBookId,
          bookTitle: book?.title ?? record.getStringValue('book_title'),
          startedAt: startedAt,
          endedAt: Value(endedAt),
          durationSeconds: Value(record.getIntValue('duration_seconds')),
          startChapter: Value(record.getIntValue('start_chapter')),
          endChapter: Value(record.getIntValue('end_chapter')),
          updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
          deletedAt: const Value(null),
          remoteId: Value(record.id),
        ),
        syncPending: false,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reading Goals
  // ---------------------------------------------------------------------------

  Future<void> _syncReadingGoals() async {
    await _pushReadingGoals();
    await _pullReadingGoals();
  }

  Future<void> _pushReadingGoals() async {
    final record = pb.authStore.record;
    if (record == null) return;
    final userId = record.id;
    final goals = await db.getAllGoals(includeDeleted: true);

    // Push new goals
    for (final goal in goals.where(
      (g) => g.remoteId == null && g.deletedAt == null,
    )) {
      try {
        final existingRemote = await _findRemoteRecordByFilter(
          'reading_goals',
          pb.filter('year = {:year} && user = {:user}', {
            'year': goal.year,
            'user': userId,
          }),
        );
        if (existingRemote != null) {
          await _attachReadingGoalRemoteLink(goal, existingRemote);
          continue;
        }

        final remoteRecord = await pb
            .collection('reading_goals')
            .create(
              body: {
                'user': userId,
                'year': goal.year,
                'books_goal': goal.booksGoal,
                'minutes_per_day_goal': goal.minutesPerDayGoal,
                'deleted_at': '',
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(remoteRecord) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.readingGoals,
        )..where((g) => g.id.equals(goal.id))).write(
          ReadingGoalsCompanion(
            remoteId: Value(remoteRecord.id),
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('reading_goals', e, st);
      }
    }

    final updatedGoals = goals
        .where((g) => g.remoteId != null && g.syncPending)
        .toList();
    for (final goal in updatedGoals) {
      try {
        final record = await pb
            .collection('reading_goals')
            .update(
              goal.remoteId!,
              body: {
                'year': goal.year,
                'books_goal': goal.booksGoal,
                'minutes_per_day_goal': goal.minutesPerDayGoal,
                'deleted_at': goal.deletedAt?.toUtc().toIso8601String() ?? '',
              },
            );
        final remoteUpdated =
            _parseRemoteTimestamp(record) ?? _fallbackRemoteTimestamp();
        await (db.update(
          db.readingGoals,
        )..where((g) => g.id.equals(goal.id))).write(
          ReadingGoalsCompanion(
            updatedAt: Value(remoteUpdated),
            syncPending: const Value(false),
          ),
        );
      } catch (e, st) {
        _reportError('reading_goals', e, st);
      }
    }
  }

  Future<void> _pullReadingGoals() async {
    final records = await _fetchRemoteRecords('reading_goals');
    for (final record in records) {
      final existing =
          await (db.select(
            db.readingGoals,
          )..where((g) => g.remoteId.equals(record.id))).getSingleOrNull() ??
          await db.getGoalForYear(
            record.getIntValue('year'),
            includeDeleted: true,
          );
      final remoteUpdated = _parseRemoteTimestamp(record);
      final remoteDeletedAt = _parseRemoteDeletedAt(record);
      final year = record.getIntValue('year');
      final booksGoal = record.getIntValue('books_goal');
      final minutesPerDayGoal = record.getIntValue('minutes_per_day_goal');

      if (existing != null) {
        if (remoteDeletedAt != null) {
          if (existing.deletedAt == null || existing.remoteId == null) {
            await (db.update(
              db.readingGoals,
            )..where((g) => g.id.equals(existing.id))).write(
              ReadingGoalsCompanion(
                remoteId: Value(record.id),
                deletedAt: Value(remoteDeletedAt),
                updatedAt: Value(remoteDeletedAt),
                syncPending: const Value(false),
              ),
            );
          }
          continue;
        }
        if (existing.deletedAt != null) {
          if (existing.remoteId == null) {
            await (db.update(db.readingGoals)
                  ..where((g) => g.id.equals(existing.id)))
                .write(ReadingGoalsCompanion(remoteId: Value(record.id)));
          }
          if (existing.syncPending) {
            continue;
          }
          continue;
        }
        final shouldApply = remoteUpdated != null
            ? remoteUpdated.isAfter(existing.updatedAt)
            : (!existing.syncPending &&
                  (!_readingGoalMatchesRecord(existing, record) ||
                      existing.deletedAt != null));
        if (!shouldApply) {
          if (existing.remoteId == null) {
            await (db.update(db.readingGoals)
                  ..where((g) => g.id.equals(existing.id)))
                .write(ReadingGoalsCompanion(remoteId: Value(record.id)));
          }
          continue;
        }
        await (db.update(
          db.readingGoals,
        )..where((g) => g.id.equals(existing.id))).write(
          ReadingGoalsCompanion(
            remoteId: Value(record.id),
            year: Value(year),
            booksGoal: Value(booksGoal),
            minutesPerDayGoal: Value(minutesPerDayGoal),
            updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
            deletedAt: const Value(null),
            syncPending: const Value(false),
          ),
        );
        continue;
      } else {
        if (remoteDeletedAt != null) continue;
        await db.upsertGoal(
          ReadingGoalsCompanion.insert(
            id: 'rg_${record.id.substring(0, 11)}',
            year: year,
            booksGoal: Value(booksGoal),
            minutesPerDayGoal: Value(minutesPerDayGoal),
            updatedAt: Value(remoteUpdated ?? _fallbackRemoteTimestamp()),
            deletedAt: const Value(null),
            remoteId: Value(record.id),
          ),
          syncPending: false,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Deletion helpers
  // ---------------------------------------------------------------------------

  Future<void> _markRemoteDeleted({
    required String collection,
    required String? remoteId,
    required DateTime deletedAt,
  }) async {
    if (remoteId == null || remoteId.isEmpty) return;
    try {
      await pb
          .collection(collection)
          .update(
            remoteId,
            body: {'deleted_at': deletedAt.toUtc().toIso8601String()},
          );
    } catch (e) {
      log(
        'Remote soft delete failed for $collection/$remoteId: $e',
        name: 'SyncEngine',
      );
    }
  }

  /// Delete a book and all of its sync-visible dependents, but preserve
  /// historical reading sessions so stats/history survive library cleanup.
  Future<void> deleteBook(Book book) async {
    final deletedAt = DateTime.now().toUtc();
    await _markRemoteDeleted(
      collection: 'books',
      remoteId: book.remoteId,
      deletedAt: deletedAt,
    );
    await db.softDeleteBook(book.id, deletedAt: deletedAt, markPending: false);
    await _deleteLocalBookFiles(book);
  }

  /// Delete a collection and its membership links without touching the books.
  Future<void> deleteCollection(BookCollection collection) async {
    final deletedAt = DateTime.now().toUtc();
    await _markRemoteDeleted(
      collection: 'collections',
      remoteId: collection.remoteId,
      deletedAt: deletedAt,
    );
    await db.softDeleteCollection(
      collection.id,
      deletedAt: deletedAt,
      markPending: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<List<RecordModel>> _fetchRemoteRecords(String collection) async {
    if (_lastSyncAt == null) {
      return await pb.collection(collection).getFullList();
    }

    final cursorField = await _resolveRemoteCursorField(collection);
    if (cursorField == null) {
      return await pb.collection(collection).getFullList();
    }

    final filterCursor = _lastSyncAt!.toUtc().subtract(
      _incrementalPullLookback,
    );
    final filter = '$cursorField >= "${filterCursor.toIso8601String()}"';
    try {
      return await pb.collection(collection).getFullList(filter: filter);
    } catch (e, st) {
      log(
        'Incremental pull failed for $collection using $cursorField; '
        'falling back to full fetch',
        name: 'SyncEngine',
        error: e,
        stackTrace: st,
      );
      _remoteCursorFieldCache[collection] = _noRemoteCursorField;
      return await pb.collection(collection).getFullList();
    }
  }

  Future<String?> _resolveRemoteCursorField(String collection) async {
    final cached = _remoteCursorFieldCache[collection];
    if (cached != null) {
      return cached == _noRemoteCursorField ? null : cached;
    }

    final preview = await pb
        .collection(collection)
        .getList(page: 1, perPage: 1);
    if (preview.items.isEmpty) {
      _remoteCursorFieldCache[collection] = _noRemoteCursorField;
      return null;
    }

    final field = _detectRemoteCursorField(preview.items.first);
    _remoteCursorFieldCache[collection] = field ?? _noRemoteCursorField;
    return field;
  }

  Future<Book?> _findLocalBookByRemoteId(String remoteId) async {
    return (db.select(
      db.books,
    )..where((b) => b.remoteId.equals(remoteId))).getSingleOrNull();
  }

  Future<String?> _findLocalBookIdByRemoteId(String remoteId) async {
    final book = await _findLocalBookByRemoteId(remoteId);
    return book?.id;
  }

  Future<String?> _findLocalCollectionIdByRemoteId(String remoteId) async {
    final col = await (db.select(
      db.bookCollections,
    )..where((c) => c.remoteId.equals(remoteId))).getSingleOrNull();
    return col?.id;
  }

  Future<CollectionBook?> _findLocalCollectionBookByRemoteId(String remoteId) {
    return (db.select(
      db.collectionBooks,
    )..where((cb) => cb.remoteId.equals(remoteId))).getSingleOrNull();
  }

  Future<String?> _getBookRemoteId(String localBookId) async {
    final book = await db.getBookById(localBookId);
    return book?.remoteId;
  }

  Future<RecordModel?> _findRemoteRecordByFilter(
    String collection,
    String filter,
  ) async {
    try {
      return await pb.collection(collection).getFirstListItem(filter);
    } on ClientException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _attachReadingProgressRemoteLink(
    ReadingProgress progress,
    RecordModel remoteRecord,
  ) async {
    final remoteDeletedAt = _parseRemoteDeletedAt(remoteRecord);
    if (remoteDeletedAt != null) {
      await (db.update(
        db.readingProgresses,
      )..where((p) => p.id.equals(progress.id))).write(
        ReadingProgressesCompanion(
          remoteId: Value(remoteRecord.id),
          deletedAt: Value(remoteDeletedAt),
          updatedAt: Value(remoteDeletedAt),
          syncPending: const Value(false),
        ),
      );
      return;
    }

    await (db.update(db.readingProgresses)
          ..where((p) => p.id.equals(progress.id)))
        .write(ReadingProgressesCompanion(remoteId: Value(remoteRecord.id)));
  }

  Future<void> _attachReadingSessionRemoteLink(
    ReadingSession session,
    RecordModel remoteRecord,
  ) async {
    final remoteDeletedAt = _parseRemoteDeletedAt(remoteRecord);
    if (remoteDeletedAt != null) {
      await (db.update(
        db.readingSessions,
      )..where((s) => s.id.equals(session.id))).write(
        ReadingSessionsCompanion(
          remoteId: Value(remoteRecord.id),
          deletedAt: Value(remoteDeletedAt),
          updatedAt: Value(remoteDeletedAt),
          syncPending: const Value(false),
        ),
      );
      return;
    }

    await (db.update(db.readingSessions)..where((s) => s.id.equals(session.id)))
        .write(ReadingSessionsCompanion(remoteId: Value(remoteRecord.id)));
  }

  Future<void> _attachReadingGoalRemoteLink(
    ReadingGoal goal,
    RecordModel remoteRecord,
  ) async {
    final remoteDeletedAt = _parseRemoteDeletedAt(remoteRecord);
    if (remoteDeletedAt != null) {
      await (db.update(
        db.readingGoals,
      )..where((g) => g.id.equals(goal.id))).write(
        ReadingGoalsCompanion(
          remoteId: Value(remoteRecord.id),
          deletedAt: Value(remoteDeletedAt),
          updatedAt: Value(remoteDeletedAt),
          syncPending: const Value(false),
        ),
      );
      return;
    }

    await (db.update(db.readingGoals)..where((g) => g.id.equals(goal.id)))
        .write(ReadingGoalsCompanion(remoteId: Value(remoteRecord.id)));
  }

  String? _detectRemoteCursorField(RecordModel record) {
    for (final field in _remoteCursorFieldCandidates) {
      if (record.data.containsKey(field)) return field;
    }
    return null;
  }

  DateTime? _parseRemoteTimestamp(RecordModel record) {
    final field = _detectRemoteCursorField(record);
    if (field == null) return null;
    final raw = record.getStringValue(field);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  DateTime? _parseRemoteDeletedAt(RecordModel record) {
    final raw = record.getStringValue('deleted_at');
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  DateTime _fallbackRemoteTimestamp() {
    return _syncStartedAt ?? _lastSyncAt ?? DateTime.now().toUtc();
  }

  bool _bookMatchesRecord(Book existing, RecordModel record) {
    final publishDateStr = record.getStringValue('publish_date');
    final remotePublishDate = publishDateStr.isNotEmpty
        ? DateTime.tryParse(publishDateStr)
        : null;
    final remoteFormat = record.getStringValue('format').isNotEmpty
        ? record.getStringValue('format')
        : 'epub';
    return existing.title == record.getStringValue('title') &&
        existing.author == record.getStringValue('author') &&
        (existing.description ?? '') == record.getStringValue('description') &&
        (existing.isbn ?? '') == record.getStringValue('isbn') &&
        (existing.language ?? '') == record.getStringValue('language') &&
        (existing.publisher ?? '') == record.getStringValue('publisher') &&
        existing.publishDate?.toUtc() == remotePublishDate?.toUtc() &&
        existing.totalChapters == record.getIntValue('total_chapters') &&
        (existing.fileHash ?? '') == record.getStringValue('file_hash') &&
        existing.format == remoteFormat;
  }

  bool _readingProgressMatchesRecord(
    ReadingProgress existing,
    RecordModel record,
  ) {
    return existing.currentChapter == record.getIntValue('current_chapter') &&
        existing.chapterProgress == record.getDoubleValue('chapter_progress') &&
        existing.overallProgress == record.getDoubleValue('overall_progress') &&
        (existing.lastPosition ?? '') ==
            record.getStringValue('last_position') &&
        existing.lastReadAt.toUtc() ==
            (DateTime.tryParse(record.getStringValue('last_read_at')) ??
                    existing.lastReadAt)
                .toUtc();
  }

  bool _highlightMatchesRecord(Highlight existing, RecordModel record) {
    return existing.selectedText == record.getStringValue('selected_text') &&
        existing.color == record.getStringValue('color') &&
        (existing.note ?? '') == record.getStringValue('note');
  }

  bool _bookmarkMatchesRecord(Bookmark existing, RecordModel record) {
    return existing.chapterIndex == record.getIntValue('chapter_index') &&
        (existing.cfi ?? '') == record.getStringValue('cfi') &&
        existing.title == record.getStringValue('title');
  }

  bool _collectionMatchesRecord(BookCollection existing, RecordModel record) {
    return existing.name == record.getStringValue('name') &&
        (existing.description ?? '') == record.getStringValue('description');
  }

  bool _readingGoalMatchesRecord(ReadingGoal existing, RecordModel record) {
    return existing.year == record.getIntValue('year') &&
        existing.booksGoal == record.getIntValue('books_goal') &&
        existing.minutesPerDayGoal ==
            record.getIntValue('minutes_per_day_goal');
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
      'deleted_at': book.deletedAt?.toUtc().toIso8601String() ?? '',
      'user': userId,
    };
  }

  BooksCompanion _recordToBookCompanion(
    RecordModel record,
    Book existing,
    DateTime remoteUpdated,
  ) {
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
      format: Value(
        record.getStringValue('format').isNotEmpty
            ? record.getStringValue('format')
            : 'epub',
      ),
      updatedAt: Value(remoteUpdated),
      deletedAt: const Value(null),
      syncPending: const Value(false),
    );
  }

  Future<void> _deleteLocalBookFiles(Book book) async {
    try {
      final file = File(PathResolver.resolve(book.filePath));
      if (await file.exists()) await file.delete();
    } catch (_) {}

    final coverPath = book.coverPath;
    if (coverPath == null || coverPath.isEmpty) return;
    try {
      final cover = File(PathResolver.resolve(coverPath));
      if (await cover.exists()) await cover.delete();
    } catch (_) {}
  }
}
