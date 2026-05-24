import 'package:equatable/equatable.dart';

import '../../../core/services/opds_catalog_service.dart';

enum SearchStatus { initial, loading, loaded, error }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<CatalogSource> catalogs;
  final String? selectedCatalogId;
  final List<CatalogBrowsePage> browseStack;
  final List<CatalogBook> results;
  final List<String> downloadingBookIds;
  final List<String> downloadedBookIds;
  final String query;
  final CatalogErrorCode? errorCode;

  const SearchState({
    this.status = SearchStatus.initial,
    this.catalogs = const [],
    this.selectedCatalogId,
    this.browseStack = const [],
    this.results = const [],
    this.downloadingBookIds = const [],
    this.downloadedBookIds = const [],
    this.query = '',
    this.errorCode,
  });

  CatalogSource? get selectedCatalog {
    if (selectedCatalogId == null) return null;
    for (final catalog in catalogs) {
      if (catalog.id == selectedCatalogId) return catalog;
    }
    return null;
  }

  CatalogBrowsePage? get currentBrowsePage =>
      browseStack.isEmpty ? null : browseStack.last;

  bool get isAtCatalogList => selectedCatalogId == null;
  bool get isShowingSearchResults => query.trim().isNotEmpty;
  bool get canSearchCurrentCatalog => selectedCatalog?.supportsSearch ?? false;

  SearchState copyWith({
    SearchStatus? status,
    List<CatalogSource>? catalogs,
    String? selectedCatalogId,
    bool clearSelectedCatalog = false,
    List<CatalogBrowsePage>? browseStack,
    List<CatalogBook>? results,
    List<String>? downloadingBookIds,
    List<String>? downloadedBookIds,
    String? query,
    CatalogErrorCode? errorCode,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      catalogs: catalogs ?? this.catalogs,
      selectedCatalogId: clearSelectedCatalog
          ? null
          : (selectedCatalogId ?? this.selectedCatalogId),
      browseStack: browseStack ?? this.browseStack,
      results: results ?? this.results,
      downloadingBookIds: downloadingBookIds ?? this.downloadingBookIds,
      downloadedBookIds: downloadedBookIds ?? this.downloadedBookIds,
      query: query ?? this.query,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }

  @override
  List<Object?> get props => [
    status,
    catalogs,
    selectedCatalogId,
    browseStack,
    results,
    downloadingBookIds,
    downloadedBookIds,
    query,
    errorCode,
  ];
}
