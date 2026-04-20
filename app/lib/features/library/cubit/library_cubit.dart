import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/models.dart';
import '../../../core/services/book_service.dart';
import '../../../core/services/path_resolver.dart';
import 'library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  final db.AppDatabase _database;
  final BookService _bookService;
  StreamSubscription? _booksSubscription;
  bool _isImporting = false;

  LibraryCubit({
    required db.AppDatabase database,
    required BookService bookService,
  })  : _database = database,
        _bookService = bookService,
        super(const LibraryState());

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

        emit(state.copyWith(
          status: LibraryStatus.loaded,
          books: books,
          progressMap: progressMap,
        ));
      },
      onError: (error) {
        emit(state.copyWith(
          status: LibraryStatus.error,
          errorMessage: error.toString(),
        ));
      },
    );
  }

  Future<void> importBook() async {
    if (_isImporting) return;
    _isImporting = true;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: BookFormat.allExtensions,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        if (file.path == null) continue;
        await _importSingleBook(file.path!);
      }
    } catch (e) {
      emit(state.copyWith(
        status: LibraryStatus.error,
        errorMessage: 'Failed to import book: $e',
      ));
    } finally {
      _isImporting = false;
    }
  }

  Future<void> _importSingleBook(String filePath) async {
    final book = await _bookService.importBook(filePath);

    await _database.insertBook(db.BooksCompanion.insert(
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
    ));
  }

  Future<void> deleteBook(String bookId) async {
    await _database.deleteBook(bookId);
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

  @override
  Future<void> close() {
    _booksSubscription?.cancel();
    return super.close();
  }
}
