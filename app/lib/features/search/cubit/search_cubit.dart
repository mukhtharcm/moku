import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/services/book_service.dart';
import '../../../core/services/opds_catalog_service.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final OpdsCatalogService _catalogService;
  final BookService _bookService;
  final db.AppDatabase _database;
  Timer? _debounce;

  SearchCubit({
    required OpdsCatalogService catalogService,
    required BookService bookService,
    required db.AppDatabase database,
  }) : _catalogService = catalogService,
       _bookService = bookService,
       _database = database,
       super(const SearchState());

  Future<void> loadCatalogs() async {
    final catalogs = await _catalogService.loadCatalogs();
    emit(
      state.copyWith(
        catalogs: catalogs,
        selectedCatalogId: state.selectedCatalogId ?? catalogs.firstOrNull?.id,
        clearError: true,
      ),
    );
  }

  void search(String query) {
    _debounce?.cancel();
    emit(state.copyWith(query: query));

    if (query.trim().isEmpty) {
      emit(state.copyWith(status: SearchStatus.initial, results: []));
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void selectCatalog(String catalogId) {
    emit(state.copyWith(selectedCatalogId: catalogId, clearError: true));

    if (state.query.trim().isNotEmpty) {
      _performSearch(state.query);
    }
  }

  Future<void> addCustomCatalog({
    required String title,
    required String url,
  }) async {
    final added = await _catalogService.addCustomCatalog(
      title: title,
      url: url,
    );
    final catalogs = await _catalogService.loadCatalogs();
    emit(
      state.copyWith(
        catalogs: catalogs,
        selectedCatalogId: added.id,
        clearError: true,
      ),
    );

    if (state.query.trim().isNotEmpty) {
      await _performSearch(state.query);
    }
  }

  Future<void> removeCustomCatalog(String catalogId) async {
    final selectedId = state.selectedCatalogId;
    await _catalogService.removeCustomCatalog(catalogId);
    final catalogs = await _catalogService.loadCatalogs();
    emit(
      state.copyWith(
        catalogs: catalogs,
        selectedCatalogId: selectedId == catalogId
            ? catalogs.firstOrNull?.id
            : selectedId,
        clearError: true,
      ),
    );

    if (state.query.trim().isNotEmpty) {
      await _performSearch(state.query);
    }
  }

  Future<void> downloadBook(CatalogBook book) async {
    final downloading = [...state.downloadingBookIds, book.id];
    emit(state.copyWith(downloadingBookIds: downloading, clearError: true));

    String? downloadedPath;
    try {
      downloadedPath = await _catalogService.downloadAcquisition(
        book.preferredAcquisition,
        suggestedName: book.title,
      );
      final imported = await _bookService.importBook(downloadedPath);
      await _database.insertBook(
        db.BooksCompanion.insert(
          id: imported.id,
          title: imported.title,
          author: imported.author,
          description: Value(imported.description),
          coverPath: Value(imported.coverPath),
          filePath: imported.filePath,
          format: Value(imported.format.name),
          isbn: Value(imported.isbn),
          language: Value(imported.language),
          publisher: Value(imported.publisher),
          publishDate: Value(imported.publishDate),
          totalChapters: Value(imported.totalChapters),
          fileHash: Value(imported.fileHash),
          createdAt: imported.createdAt,
          updatedAt: imported.updatedAt,
        ),
      );
    } finally {
      final updated = [...state.downloadingBookIds]..remove(book.id);
      emit(state.copyWith(downloadingBookIds: updated));
      if (downloadedPath != null) {
        final tempPath = downloadedPath;
        unawaited(() async {
          try {
            await File(tempPath).delete();
          } catch (_) {}
        }());
      }
    }
  }

  Future<void> _performSearch(String query) async {
    final catalog = state.selectedCatalog;
    if (catalog == null) {
      emit(state.copyWith(status: SearchStatus.error, clearError: true));
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, clearError: true));

    try {
      final results = await _catalogService.searchBooks(catalog, query);
      emit(state.copyWith(status: SearchStatus.loaded, results: results));
    } catch (e) {
      emit(
        state.copyWith(status: SearchStatus.error, errorMessage: e.toString()),
      );
    }
  }

  void clear() {
    _debounce?.cancel();
    emit(
      state.copyWith(
        status: SearchStatus.initial,
        results: const [],
        query: '',
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _catalogService.dispose();
    return super.close();
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
