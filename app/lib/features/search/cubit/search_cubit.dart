import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/services/book_service.dart';
import '../../../core/services/opds_catalog_service.dart';
import '../../../core/sync/auto_sync_service.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final OpdsCatalogService _catalogService;
  final BookService _bookService;
  final db.AppDatabase _database;
  final AutoSyncService? _autoSync;
  final Duration _searchDebounce;
  Timer? _debounce;
  int _searchRevision = 0;

  SearchCubit({
    required OpdsCatalogService catalogService,
    required BookService bookService,
    required db.AppDatabase database,
    AutoSyncService? autoSync,
    Duration searchDebounce = const Duration(milliseconds: 500),
  }) : _catalogService = catalogService,
       _bookService = bookService,
       _database = database,
       _autoSync = autoSync,
       _searchDebounce = searchDebounce,
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
    final revision = ++_searchRevision;
    emit(state.copyWith(query: query, clearError: true));

    if (query.trim().isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.initial,
          results: const [],
          clearError: true,
        ),
      );
      return;
    }

    _debounce = Timer(_searchDebounce, () {
      unawaited(_performSearch(query, revision));
    });
  }

  Future<void> submitSearch([String? query]) async {
    _debounce?.cancel();
    final normalized = (query ?? state.query).trim();
    final revision = ++_searchRevision;
    emit(state.copyWith(query: query ?? state.query, clearError: true));

    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.initial,
          results: const [],
          clearError: true,
        ),
      );
      return;
    }

    await _performSearch(normalized, revision);
  }

  void selectCatalog(String catalogId) {
    emit(state.copyWith(selectedCatalogId: catalogId, clearError: true));

    if (state.query.trim().isNotEmpty) {
      unawaited(_performSearch(state.query, ++_searchRevision));
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
      await _performSearch(state.query, ++_searchRevision);
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
      await _performSearch(state.query, ++_searchRevision);
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
      _autoSync?.bump();
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

  Future<void> _performSearch(String query, int revision) async {
    if (revision != _searchRevision) return;

    final catalog = state.selectedCatalog;
    if (catalog == null) {
      if (revision != _searchRevision) return;
      emit(state.copyWith(status: SearchStatus.error, clearError: true));
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, clearError: true));

    try {
      final results = await _catalogService.searchBooks(catalog, query);
      if (revision != _searchRevision) return;
      emit(state.copyWith(status: SearchStatus.loaded, results: results));
    } on CatalogException catch (e) {
      if (revision != _searchRevision) return;
      emit(state.copyWith(status: SearchStatus.error, errorCode: e.code));
    } catch (_) {
      if (revision != _searchRevision) return;
      emit(state.copyWith(status: SearchStatus.error, clearError: true));
    }
  }

  void clear() {
    _debounce?.cancel();
    _searchRevision++;
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
