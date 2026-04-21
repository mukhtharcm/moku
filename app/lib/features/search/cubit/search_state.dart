import 'package:equatable/equatable.dart';
import '../../../core/services/opds_catalog_service.dart';

enum SearchStatus { initial, loading, loaded, error }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<CatalogBook> results;
  final List<CatalogSource> catalogs;
  final String? selectedCatalogId;
  final List<String> downloadingBookIds;
  final String query;
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.results = const [],
    this.catalogs = const [],
    this.selectedCatalogId,
    this.downloadingBookIds = const [],
    this.query = '',
    this.errorMessage,
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
    String? query,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      catalogs: catalogs ?? this.catalogs,
      selectedCatalogId: selectedCatalogId ?? this.selectedCatalogId,
      downloadingBookIds: downloadingBookIds ?? this.downloadingBookIds,
      query: query ?? this.query,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    results,
    catalogs,
    selectedCatalogId,
    downloadingBookIds,
    query,
    errorMessage,
  ];
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
