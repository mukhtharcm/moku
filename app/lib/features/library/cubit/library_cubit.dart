import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/database.dart' as db;
import '../../../core/models/models.dart';
import '../../../core/platform/incoming_file_imports.dart';
import '../../../core/services/book_service.dart';
import '../../../core/services/path_resolver.dart';
import '../../../core/sync/auto_sync_service.dart';
import 'library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  final db.AppDatabase _database;
  final BookService _bookService;
  final AutoSyncService? _autoSync;
  StreamSubscription? _booksSubscription;
  StreamSubscription<List<String>>? _incomingImportsSubscription;
  Future<void> _importTail = Future<void>.value();
  bool _isPickingFiles = false;

  LibraryCubit({
    required db.AppDatabase database,
    required BookService bookService,
    AutoSyncService? autoSync,
  }) : _database = database,
       _bookService = bookService,
       _autoSync = autoSync,
       super(const LibraryState()) {
    _listenForIncomingImports();
  }

  void loadBooks() {
    emit(state.copyWith(status: LibraryStatus.loading));
    _booksSubscription?.cancel();
    _booksSubscription = _database.watchAllBooks().listen(
      (dbBooks) async {
        final books = dbBooks.map(_mapDbBookToModel).toList();

        // Load reading progress for all books
        final progressMap = <String, double>{};
        for (final book in dbBooks) {
          final progress = await _database.getProgressForBook(book.id);
          if (progress != null) {
            progressMap[book.id] = progress.overallProgress;
          }
        }

        emit(
          state.copyWith(
            status: LibraryStatus.loaded,
            books: books,
            progressMap: progressMap,
          ),
        );
      },
      onError: (error) {
        emit(state.copyWith(status: LibraryStatus.error));
      },
    );
  }

  Future<void> importBook() async {
    if (_isPickingFiles) return;
    _isPickingFiles = true;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: BookFormat.allExtensions,
        allowMultiple: true,
        withReadStream: Platform.isIOS || Platform.isAndroid,
      );

      if (result == null || result.files.isEmpty) return;

      await _enqueueImportBatch(() async {
        for (final file in result.files) {
          await _importPlatformFile(file);
        }
      });
    } catch (e, stack) {
      _emitImportError('importBook', e, stack);
    } finally {
      _isPickingFiles = false;
    }
  }

  void _listenForIncomingImports() {
    final incomingImports = IncomingFileImports.instance..configure();
    _incomingImportsSubscription = incomingImports.paths.listen((paths) {
      unawaited(_importIncomingPaths(paths));
    });
    unawaited(_importPendingIncomingPaths(incomingImports));
  }

  Future<void> _importPendingIncomingPaths(
    IncomingFileImports incomingImports,
  ) async {
    final paths = await incomingImports.takePendingPaths();
    if (paths.isNotEmpty) {
      await _importIncomingPaths(paths);
    }
  }

  Future<void> _importIncomingPaths(List<String> paths) async {
    try {
      await _enqueueImportBatch(() async {
        for (final path in paths) {
          await _importExternalPath(path);
        }
      });
    } catch (e, stack) {
      _emitImportError('incoming file import', e, stack);
    }
  }

  Future<void> _enqueueImportBatch(Future<void> Function() importBatch) {
    final next = _importTail.then(
      (_) => importBatch(),
      onError: (_, _) => importBatch(),
    );
    _importTail = next.catchError((_) {});
    return next;
  }

  Future<void> _importPlatformFile(PlatformFile file) async {
    final stagedPath = await _stagePlatformFile(file);
    if (stagedPath == null) return;
    await _importStagedBook(stagedPath);
  }

  Future<void> _importExternalPath(String filePath) async {
    final stagedPath = await _stageFileFromPath(filePath);
    await _importStagedBook(stagedPath);
  }

  Future<void> _importStagedBook(String stagedPath) async {
    try {
      await _importSingleBook(stagedPath);
    } finally {
      await _deleteFileIfExists(stagedPath);
    }
  }

  Future<String?> _stagePlatformFile(PlatformFile file) async {
    final sourceName = file.name.isNotEmpty
        ? file.name
        : file.path == null
        ? 'book'
        : p.basename(file.path!);

    if (file.readStream != null) {
      final stagedPath = await _stagedImportPath(sourceName);
      final stagedFile = File(stagedPath);
      final sink = stagedFile.openWrite();
      var closed = false;
      try {
        await sink.addStream(file.readStream!);
        await sink.close();
        closed = true;
        return stagedPath;
      } catch (_) {
        if (!closed) {
          try {
            await sink.close();
          } catch (_) {}
        }
        await _deleteFileIfExists(stagedPath);
        rethrow;
      }
    }

    if (file.bytes != null) {
      final stagedPath = await _stagedImportPath(sourceName);
      try {
        await File(stagedPath).writeAsBytes(file.bytes!, flush: true);
        return stagedPath;
      } catch (_) {
        await _deleteFileIfExists(stagedPath);
        rethrow;
      }
    }

    if (file.path != null) {
      return _stageFileFromPath(file.path!, fileName: sourceName);
    }

    return null;
  }

  Future<String> _stageFileFromPath(
    String sourcePath, {
    String? fileName,
  }) async {
    final stagedPath = await _stagedImportPath(
      fileName ?? p.basename(sourcePath),
    );
    try {
      await File(sourcePath).copy(stagedPath);
      return stagedPath;
    } catch (_) {
      await _deleteFileIfExists(stagedPath);
      rethrow;
    }
  }

  Future<String> _stagedImportPath(String fileName) async {
    final importDir = Directory(p.join(PathResolver.basePath, 'moku_imports'));
    if (!await importDir.exists()) {
      await importDir.create(recursive: true);
    }

    final safeName = _safeImportFileName(fileName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(importDir.path, '${stamp}_$safeName');
  }

  String _safeImportFileName(String fileName) {
    final basename = p.basename(fileName).trim();
    final safeName = basename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      return 'book';
    }
    return safeName;
  }

  Future<void> _importSingleBook(String filePath) async {
    final book = await _bookService.importBook(filePath);

    await _database.insertBook(
      db.BooksCompanion.insert(
        id: book.id,
        title: book.title,
        author: book.author,
        description: Value(book.description),
        coverPath: Value(book.coverPath),
        filePath: book.filePath,
        format: Value(book.format.name),
        isbn: Value(book.isbn),
        language: Value(book.language),
        publisher: Value(book.publisher),
        publishDate: Value(book.publishDate),
        totalChapters: Value(book.totalChapters),
        fileHash: Value(book.fileHash),
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
      ),
    );
    _autoSync?.bump();
  }

  /// Deletes the book record from the database AND removes its associated
  /// files (epub/pdf/etc. and cover image) from disk to prevent orphan
  /// storage accumulation.
  Future<void> deleteBook(String bookId) async {
    // Fetch file paths before deleting the DB record
    final bookRecord = await _database.getBookById(
      bookId,
      includeDeleted: true,
    );

    // Tombstone in the database first so sync can propagate the delete.
    await _database.softDeleteBook(bookId);
    _autoSync?.bump();
    _autoSync?.flushNow();

    // Clean up files from disk (best-effort — never throw on failure)
    if (bookRecord != null) {
      await _deleteFileIfExists(PathResolver.resolve(bookRecord.filePath));
      if (bookRecord.coverPath != null) {
        await _deleteFileIfExists(PathResolver.resolve(bookRecord.coverPath!));
      }
    }
  }

  /// Deletes a file from disk, silently ignoring errors (file already
  /// deleted, permission denied, etc.).
  Future<void> _deleteFileIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort: never crash the delete flow over a file cleanup failure
    }
  }

  void _emitImportError(String source, Object error, StackTrace stack) {
    // ignore: avoid_print
    print('[LibraryCubit] $source failed: $error\n$stack');
    emit(
      state.copyWith(
        status: LibraryStatus.error,
        errorMessage: error.toString(),
      ),
    );
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void toggleViewMode() {
    final nextMode = state.viewMode == LibraryView.grid
        ? LibraryView.list
        : LibraryView.grid;
    emit(state.copyWith(viewMode: nextMode));
  }

  void setSortMode(LibrarySortMode mode) {
    emit(state.copyWith(sortMode: mode));
  }

  void selectBook(String? bookId) {
    emit(
      state.copyWith(selectedBookId: bookId, clearSelectedBook: bookId == null),
    );
  }

  @override
  Future<void> close() {
    _booksSubscription?.cancel();
    _incomingImportsSubscription?.cancel();
    return super.close();
  }

  Book _mapDbBookToModel(db.Book dbBook) {
    return Book(
      id: dbBook.id,
      title: dbBook.title,
      author: dbBook.author,
      description: dbBook.description,
      coverPath: PathResolver.resolveNullable(dbBook.coverPath),
      filePath: PathResolver.resolve(dbBook.filePath),
      format: BookFormat.values.firstWhere(
        (f) => f.name == dbBook.format,
        orElse: () => BookFormat.epub,
      ),
      isbn: dbBook.isbn,
      language: dbBook.language,
      publisher: dbBook.publisher,
      publishDate: dbBook.publishDate,
      totalChapters: dbBook.totalChapters,
      fileHash: dbBook.fileHash,
      createdAt: dbBook.createdAt,
      updatedAt: dbBook.updatedAt,
      remoteId: dbBook.remoteId,
    );
  }
}
