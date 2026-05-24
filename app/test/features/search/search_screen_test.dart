import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/database/database.dart' hide Book;
import 'package:moku/core/models/book.dart' as book_model;
import 'package:moku/core/services/book_service.dart';
import 'package:moku/core/services/opds_catalog_service.dart';
import 'package:moku/features/search/cubit/search_cubit.dart';
import 'package:moku/features/search/cubit/search_state.dart';
import 'package:moku/features/search/screens/search_screen.dart';
import 'package:moku/l10n/l10n.dart';

void main() {
  testWidgets(
    'clear action is labeled and stale search responses are ignored',
    (tester) async {
      final searchCompleter = Completer<List<CatalogBook>>();
      final searchQueries = <String>[];
      final database = AppDatabase(NativeDatabase.memory());
      final catalogService = _FakeOpdsCatalogService(
        catalogs: const [
          CatalogSource(
            id: 'open-library',
            title: '',
            url: 'https://openlibrary.org/opds/',
            kind: CatalogKind.openLibrary,
            protocol: CatalogProtocol.opds2,
          ),
        ],
        onSearch: (_, query) {
          searchQueries.add(query);
          return searchCompleter.future;
        },
      );
      final cubit = SearchCubit(
        catalogService: catalogService,
        bookService: BookService(),
        database: database,
        searchDebounce: Duration.zero,
      )..loadCatalogs();

      addTearDown(() async {
        await cubit.close();
        await database.close();
      });

      await tester.pumpWidget(_buildTestApp(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Search Open Library'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Alice');
      await tester.pump();

      expect(find.byTooltip('Clear'), findsOneWidget);
      expect(searchQueries, ['Alice']);
      expect(cubit.state.status, SearchStatus.loading);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();

      expect(cubit.state.query, isEmpty);
      expect(cubit.state.status, SearchStatus.initial);
      expect(find.text('Search Open Library'), findsOneWidget);
      expect(find.text('No downloadable books found'), findsNothing);

      searchCompleter.complete(const []);
      await tester.pump();

      expect(cubit.state.query, isEmpty);
      expect(cubit.state.status, SearchStatus.initial);
      expect(cubit.state.results, isEmpty);
      expect(find.text('Search Open Library'), findsOneWidget);
      expect(find.text('No downloadable books found'), findsNothing);
    },
  );

  testWidgets('empty search results stay visible after a completed search', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final catalogService = _FakeOpdsCatalogService(
      catalogs: const [
        CatalogSource(
          id: 'open-library',
          title: '',
          url: 'https://openlibrary.org/opds/',
          kind: CatalogKind.openLibrary,
          protocol: CatalogProtocol.opds2,
        ),
      ],
      onSearch: (_, query) async => const [],
    );
    final cubit = SearchCubit(
      catalogService: catalogService,
      bookService: BookService(),
      database: database,
      searchDebounce: Duration.zero,
    )..loadCatalogs();

    addTearDown(() async {
      await cubit.close();
      await database.close();
    });

    await tester.pumpWidget(_buildTestApp(cubit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Alice');
    await tester.pumpAndSettle();

    expect(find.text('No downloadable books found'), findsOneWidget);
  });

  test('downloaded ids are tracked after a successful import', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final tempFile = File(
      '${Directory.systemTemp.path}/moku-search-test-${DateTime.now().microsecondsSinceEpoch}.epub',
    );
    await tempFile.writeAsString('fake epub payload');
    final acquisitionUrl = Uri.parse('https://example.com/alice.epub');

    final resultBook = CatalogBook(
      id: 'open-library:alice',
      title: 'Alice',
      author: 'Lewis Carroll',
      catalogId: 'open-library',
      catalogTitle: 'Open Library',
      acquisitions: [
        CatalogAcquisition(
          url: acquisitionUrl,
          mediaType: 'application/epub+zip',
          format: book_model.BookFormat.epub,
        ),
      ],
    );

    final catalogService = _FakeOpdsCatalogService(
      catalogs: const [
        CatalogSource(
          id: 'open-library',
          title: '',
          url: 'https://openlibrary.org/opds/',
          kind: CatalogKind.openLibrary,
          protocol: CatalogProtocol.opds2,
        ),
      ],
      onSearch: (_, query) async => [resultBook],
      onDownload: (_) async => tempFile.path,
    );
    final cubit = SearchCubit(
      catalogService: catalogService,
      bookService: _FakeBookService(),
      database: database,
      searchDebounce: Duration.zero,
    )..loadCatalogs();

    addTearDown(() async {
      await cubit.close();
      await database.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    await cubit.downloadBook(resultBook);
    expect(cubit.state.downloadedBookIds, contains('open-library:alice'));
  });
}

Widget _buildTestApp(SearchCubit cubit) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: false),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SearchCubit>.value(
      value: cubit,
      child: const SearchScreen(),
    ),
  );
}

class _FakeOpdsCatalogService extends OpdsCatalogService {
  final List<CatalogSource> catalogs;
  final Future<List<CatalogBook>> Function(CatalogSource catalog, String query)
  onSearch;
  final Future<String> Function(CatalogAcquisition acquisition)? onDownload;

  _FakeOpdsCatalogService({
    required this.catalogs,
    required this.onSearch,
    this.onDownload,
  });

  @override
  Future<List<CatalogSource>> loadCatalogs() async => catalogs;

  @override
  Future<List<CatalogBook>> searchBooks(CatalogSource catalog, String query) =>
      onSearch(catalog, query);

  @override
  Future<String> downloadAcquisition(
    CatalogAcquisition acquisition, {
    required String suggestedName,
  }) async {
    if (onDownload == null) {
      throw UnimplementedError('downloadAcquisition was not configured');
    }
    return onDownload!(acquisition);
  }

  @override
  void dispose() {}
}

class _FakeBookService extends BookService {
  @override
  Future<book_model.Book> importBook(String filePath) async {
    return book_model.Book(
      id: 'imported-book',
      title: 'Alice',
      author: 'Lewis Carroll',
      filePath: filePath,
      format: book_model.BookFormat.epub,
      createdAt: DateTime.utc(2026, 5, 24),
      updatedAt: DateTime.utc(2026, 5, 24),
    );
  }
}
