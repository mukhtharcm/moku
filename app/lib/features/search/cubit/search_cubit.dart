import '../../../core/ui/ui.dart';
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    Duration searchDebounce = MokuMotion.slow,
  }) : _catalogService = catalogService,
       _bookService = bookService,
       _database = database,
       _autoSync = autoSync,
       _searchDebounce = searchDebounce,
       super(const SearchState());

  Future<void> loadCatalogs() async {
    final catalogs = await _catalogService.loadCatalogs();
    final selectedCatalogId = state.selectedCatalogId;
    final hasSelected = catalogs.any((catalog) => catalog.id == selectedCatalogId);
    emit(
      state.copyWith(
        catalogs: catalogs,
        clearSelectedCatalog: selectedCatalogId != null && !hasSelected,
        browseStack: selectedCatalogId != null && !hasSelected
            ? const []
            : state.browseStack,
        results: selectedCatalogId != null && !hasSelected ? const [] : state.results,
        query: selectedCatalogId != null && !hasSelected ? '' : state.query,
        status: selectedCatalogId != null && !hasSelected
            ? SearchStatus.initial
            : state.status,
        clearError: true,
      ),
    );
  }

  Future<void> openCatalog(String catalogId) async {
    final catalog = state.catalogs.firstWhereOrNull((item) => item.id == catalogId);
    if (catalog == null) return;

    _debounce?.cancel();
    _searchRevision++;
    emit(
      state.copyWith(
        selectedCatalogId: catalogId,
        browseStack: const [],
        results: const [],
        query: '',
        status: SearchStatus.loading,
        clearError: true,
      ),
    );

    try {
      final page = await _catalogService.loadCatalogPage(catalog);
      emit(
        state.copyWith(
          selectedCatalogId: catalogId,
          browseStack: [page],
          results: const [],
          query: '',
          status: SearchStatus.loaded,
          clearError: true,
        ),
      );
    } on CatalogException catch (error) {
      emit(
        state.copyWith(
          selectedCatalogId: catalogId,
          browseStack: const [],
          results: const [],
          query: '',
          status: SearchStatus.error,
          errorCode: error.code,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          selectedCatalogId: catalogId,
          browseStack: const [],
          results: const [],
          query: '',
          status: SearchStatus.error,
          clearError: true,
        ),
      );
    }
  }

  Future<void> openBrowseEntry(CatalogNavigationEntry entry) async {
    final catalog = state.selectedCatalog;
    if (catalog == null) return;

    _debounce?.cancel();
    _searchRevision++;
    emit(
      state.copyWith(
        query: '',
        results: const [],
        status: SearchStatus.loading,
        clearError: true,
      ),
    );

    try {
      final page = await _catalogService.loadCatalogPage(catalog, pageUri: entry.uri);
      emit(
        state.copyWith(
          browseStack: [...state.browseStack, page],
          query: '',
          results: const [],
          status: SearchStatus.loaded,
          clearError: true,
        ),
      );
    } on CatalogException catch (error) {
      emit(state.copyWith(status: SearchStatus.error, errorCode: error.code));
    } catch (_) {
      emit(state.copyWith(status: SearchStatus.error, clearError: true));
    }
  }

  void back() {
    _debounce?.cancel();
    _searchRevision++;

    if (state.query.trim().isNotEmpty) {
      emit(
        state.copyWith(
          query: '',
          results: const [],
          status: SearchStatus.loaded,
          clearError: true,
        ),
      );
      return;
    }

    if (state.browseStack.length > 1) {
      emit(
        state.copyWith(
          browseStack: state.browseStack.sublist(0, state.browseStack.length - 1),
          status: SearchStatus.loaded,
          clearError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        clearSelectedCatalog: true,
        browseStack: const [],
        results: const [],
        query: '',
        status: SearchStatus.initial,
        clearError: true,
      ),
    );
  }

  void search(String query) {
    final catalog = state.selectedCatalog;
    if (catalog == null || !catalog.supportsSearch) return;

    _debounce?.cancel();
    final normalized = query.trim();
    final revision = ++_searchRevision;
    emit(state.copyWith(query: query, clearError: true));

    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.loaded,
          results: const [],
          clearError: true,
        ),
      );
      return;
    }

    _debounce = Timer(_searchDebounce, () {
      unawaited(_performSearch(normalized, revision));
    });
  }

  Future<void> submitSearch([String? query]) async {
    final catalog = state.selectedCatalog;
    if (catalog == null || !catalog.supportsSearch) return;

    _debounce?.cancel();
    final normalized = (query ?? state.query).trim();
    final revision = ++_searchRevision;
    emit(state.copyWith(query: query ?? state.query, clearError: true));

    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.loaded,
          results: const [],
          clearError: true,
        ),
      );
      return;
    }

    await _performSearch(normalized, revision);
  }

  Future<void> addCustomCatalog({
    required String title,
    required String url,
  }) async {
    final added = await _catalogService.addCustomCatalog(title: title, url: url);
    final catalogs = await _catalogService.loadCatalogs();
    emit(state.copyWith(catalogs: catalogs, clearError: true));
    await openCatalog(added.id);
  }

  Future<void> removeCustomCatalog(String catalogId) async {
    final isCurrentCatalog = state.selectedCatalogId == catalogId;
    await _catalogService.removeCustomCatalog(catalogId);
    final catalogs = await _catalogService.loadCatalogs();
    emit(
      state.copyWith(
        catalogs: catalogs,
        clearSelectedCatalog: isCurrentCatalog,
        browseStack: isCurrentCatalog ? const [] : state.browseStack,
        results: isCurrentCatalog ? const [] : state.results,
        query: isCurrentCatalog ? '' : state.query,
        status: isCurrentCatalog ? SearchStatus.initial : state.status,
        clearError: true,
      ),
    );
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
      final downloaded = {...state.downloadedBookIds, book.id}.toList();
      emit(state.copyWith(downloadedBookIds: downloaded, clearError: true));
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
    } on CatalogException catch (error) {
      if (revision != _searchRevision) return;
      emit(state.copyWith(status: SearchStatus.error, errorCode: error.code));
    } catch (_) {
      if (revision != _searchRevision) return;
      emit(state.copyWith(status: SearchStatus.error, clearError: true));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _catalogService.dispose();
    return super.close();
  }
}

extension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T item) predicate) {
    for (final item in this) {
      if (predicate(item)) return item;
    }
    return null;
  }
}
