import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/open_library_service.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final OpenLibraryService _openLibraryService;
  Timer? _debounce;

  SearchCubit({required OpenLibraryService openLibraryService})
      : _openLibraryService = openLibraryService,
        super(const SearchState());

  void search(String query) {
    _debounce?.cancel();
    emit(state.copyWith(query: query));

    if (query.trim().isEmpty) {
      emit(state.copyWith(
        status: SearchStatus.initial,
        results: [],
      ));
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    emit(state.copyWith(status: SearchStatus.loading));

    try {
      final results = await _openLibraryService.searchBooks(query);
      emit(state.copyWith(
        status: SearchStatus.loaded,
        results: results,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void clear() {
    _debounce?.cancel();
    emit(const SearchState());
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
