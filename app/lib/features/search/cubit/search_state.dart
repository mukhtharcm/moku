import 'package:equatable/equatable.dart';
import '../../../core/services/opds_catalog_service.dart';

enum SearchStatus { initial, loading, loaded, error }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<CatalogBook> results;
  final List<CatalogSource> catalogs;
  final String? selectedCatalogId;
  final List<String> downloadingBookIds;
  final List<String> downloadedBookIds;
  final String query;
  final CatalogErrorCode? errorCode;

  const SearchState({
    this.status = SearchStatus.initial,
    this.results = const [],
    this.catalogs = const [],
    this.selectedCatalogId,
    this.downloadingBookIds = const [],
    this.downloadedBookIds = const [],
    this.query = '',
    this.errorCode,
  });

  CatalogSource? get selectedCatalog {
    if (selectedCatalogId == null) return catalogs.firstOrNull;
    for (final catalog in catalogs) {
      if (catalog.id == selectedCatalogId) return catalog;
    }
    return catalogs.firstOrNull;
  }

  SearchState copyWith({
    SearchStatus? status,
    List<CatalogBook>? results,
    List<CatalogSource>? catalogs,
    String? selectedCatalogId,
    List<String>? downloadingBookIds,
    List<String>? downloadedBookIds,
    String? query,
    CatalogErrorCode? errorCode,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      catalogs: catalogs ?? this.catalogs,
      selectedCatalogId: selectedCatalogId ?? this.selectedCatalogId,
      downloadingBookIds: downloadingBookIds ?? this.downloadingBookIds,
      downloadedBookIds: downloadedBookIds ?? this.downloadedBookIds,
      query: query ?? this.query,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }

  @override
  List<Object?> get props => [
    status,
    results,
    catalogs,
    selectedCatalogId,
    downloadingBookIds,
    downloadedBookIds,
    query,
    errorCode,
  ];
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
