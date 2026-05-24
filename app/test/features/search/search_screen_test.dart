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
  testWidgets('catalogs render as folders and searchable catalogs can search', (
    tester,
  ) async {
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
      onLoadCatalogPage: (_, pageUri) async =>
          const CatalogBrowsePage(title: ''),
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

    expect(find.text('Open Library'), findsOneWidget);

    await tester.tap(find.text('Open Library'));
    await tester.pumpAndSettle();

    expect(find.text('Search Open Library...'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Alice');
    await tester.pump();

    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(searchQueries, ['Alice']);
    expect(cubit.state.status, SearchStatus.loading);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(cubit.state.query, isEmpty);
    expect(cubit.state.status, SearchStatus.loaded);
    expect(find.text('Nothing to browse here yet.'), findsOneWidget);

    searchCompleter.complete(const []);
    await tester.pump();

    expect(cubit.state.query, isEmpty);
    expect(cubit.state.status, SearchStatus.loaded);
    expect(cubit.state.results, isEmpty);
    expect(find.text('Nothing to browse here yet.'), findsOneWidget);
  });

  testWidgets('browse-only catalogs open into navigation entries', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final catalogService = _FakeOpdsCatalogService(
      catalogs: const [
        CatalogSource(
          id: 'gopds',
          title: 'GoPDS Library',
          url: 'https://books.gorkos.net/opds',
          kind: CatalogKind.custom,
          protocol: CatalogProtocol.opds1,
        ),
      ],
      onSearch: (_, query) async => const [],
      onLoadCatalogPage: (_, pageUri) async => CatalogBrowsePage(
        title: 'GoPDS Library',
        navigationEntries: [
          CatalogNavigationEntry(
            id: 'authors',
            title: 'Authors A-D',
            uri: Uri.parse('https://books.gorkos.net/opds?authors=a-d'),
          ),
        ],
      ),
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

    await tester.tap(find.text('GoPDS Library'));
    await tester.pumpAndSettle();

    expect(find.text('Authors A-D'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'add catalog dialog shows inline error text when adding fails',
    (tester) async {
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
        onLoadCatalogPage: (_, pageUri) async =>
            const CatalogBrowsePage(title: ''),
        onAddCustomCatalog: ({required title, required url}) async {
          throw const CatalogException(CatalogErrorCode.catalogAccessDenied);
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

      await tester.tap(find.byTooltip('Manage catalogs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Custom Catalog'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Blocked Feed');
      await tester.enterText(
        fields.at(1),
        'https://catalog.feedbooks.com/catalog/index.json',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(
        find.text('This catalog denied access from the app.'),
        findsOneWidget,
      );
      expect(find.text('Add Custom Catalog'), findsOneWidget);
    },
  );

  testWidgets('add catalog dialog closes after a successful add', (
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
      onLoadCatalogPage: (catalog, pageUri) async => CatalogBrowsePage(
        title: catalog.title,
        navigationEntries: [
          CatalogNavigationEntry(
            id: 'authors',
            title: 'Authors',
            uri: Uri.parse('https://m.gutenberg.org/authors'),
          ),
        ],
      ),
      onAddCustomCatalog: ({required title, required url}) async {
        return CatalogSource(
          id: 'custom-mobile-gutenberg',
          title: title,
          url: url,
          kind: CatalogKind.custom,
          protocol: CatalogProtocol.opds1,
          searchTemplate:
              'https://m.gutenberg.org/ebooks/search.opds/?query={searchTerms}',
        );
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

    await tester.tap(find.byTooltip('Manage catalogs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Custom Catalog'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mobile Gutenberg');
    await tester.enterText(
      fields.at(1),
      'https://m.gutenberg.org/ebooks/search.opds/',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Authors'), findsOneWidget);
    expect(cubit.state.selectedCatalogId, 'custom-mobile-gutenberg');
    expect(
      cubit.state.catalogs.any(
        (catalog) => catalog.id == 'custom-mobile-gutenberg',
      ),
      isTrue,
    );
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
      onLoadCatalogPage: (_, pageUri) async =>
          const CatalogBrowsePage(title: ''),
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
  final List<CatalogSource> _catalogs;
  final Future<List<CatalogBook>> Function(CatalogSource catalog, String query)
  onSearch;
  final Future<CatalogBrowsePage> Function(CatalogSource catalog, Uri? pageUri)
  onLoadCatalogPage;
  final Future<String> Function(CatalogAcquisition acquisition)? onDownload;
  final Future<CatalogSource> Function({
    required String title,
    required String url,
  })?
  onAddCustomCatalog;

  _FakeOpdsCatalogService({
    required List<CatalogSource> catalogs,
    required this.onSearch,
    required this.onLoadCatalogPage,
    this.onDownload,
    this.onAddCustomCatalog,
  }) : _catalogs = List<CatalogSource>.from(catalogs);

  @override
  Future<List<CatalogSource>> loadCatalogs() async =>
      List<CatalogSource>.unmodifiable(_catalogs);

  @override
  Future<List<CatalogBook>> searchBooks(CatalogSource catalog, String query) =>
      onSearch(catalog, query);

  @override
  Future<CatalogBrowsePage> loadCatalogPage(
    CatalogSource catalog, {
    Uri? pageUri,
  }) => onLoadCatalogPage(catalog, pageUri);

  @override
  Future<CatalogSource> addCustomCatalog({
    required String title,
    required String url,
  }) async {
    if (onAddCustomCatalog == null) {
      throw UnimplementedError('addCustomCatalog was not configured');
    }
    final catalog = await onAddCustomCatalog!(title: title, url: url);
    _catalogs.add(catalog);
    return catalog;
  }

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
