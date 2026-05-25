import 'package:equatable/equatable.dart';
import '../../../core/models/models.dart';

enum LibraryStatus { initial, loading, loaded, error }

enum LibraryView { grid, list }

enum LibrarySortMode { recent, title, author }

class LibraryState extends Equatable {
  final LibraryStatus status;
  final List<Book> books;
  final LibraryView viewMode;
  final LibrarySortMode sortMode;
  final String? errorMessage;
  final String searchQuery;
  final Map<String, double> progressMap;
  final String? selectedBookId;

  const LibraryState({
    this.status = LibraryStatus.initial,
    this.books = const [],
    this.viewMode = LibraryView.grid,
    this.sortMode = LibrarySortMode.recent,
    this.errorMessage,
    this.searchQuery = '',
    this.progressMap = const {},
    this.selectedBookId,
  });

  LibraryState copyWith({
    LibraryStatus? status,
    List<Book>? books,
    LibraryView? viewMode,
    LibrarySortMode? sortMode,
    String? errorMessage,
    String? searchQuery,
    Map<String, double>? progressMap,
    String? selectedBookId,
    bool clearSelectedBook = false,
  }) {
    return LibraryState(
      status: status ?? this.status,
      books: books ?? this.books,
      viewMode: viewMode ?? this.viewMode,
      sortMode: sortMode ?? this.sortMode,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      progressMap: progressMap ?? this.progressMap,
      selectedBookId:
          clearSelectedBook ? null : (selectedBookId ?? this.selectedBookId),
    );
  }

  List<Book> get filteredBooks {
    var result = books.toList();
    
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((b) {
        return b.title.toLowerCase().contains(query) ||
            b.author.toLowerCase().contains(query);
      }).toList();
    }

    switch (sortMode) {
      case LibrarySortMode.title:
        result.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySortMode.author:
        result.sort((a, b) => a.author.compareTo(b.author));
      case LibrarySortMode.recent:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return result;
  }

  /// Books the user has started but not finished, sorted by last read
  List<Book> get currentlyReading {
    return books.where((b) {
      final progress = progressMap[b.id] ?? 0.0;
      return progress > 0.01 && progress < 0.98;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Book? get selectedBook {
    if (selectedBookId == null) return null;
    try {
      return books.firstWhere((b) => b.id == selectedBookId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    status, books, viewMode, sortMode, errorMessage,
    searchQuery, progressMap, selectedBookId,
  ];
}
