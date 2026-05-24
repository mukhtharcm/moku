import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/database/database.dart';
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

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SearchCubit>.value(
            value: cubit,
            child: const SearchScreen(),
          ),
        ),
      );
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

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SearchCubit>.value(
          value: cubit,
          child: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Alice');
    await tester.pumpAndSettle();

    expect(find.text('No downloadable books found'), findsOneWidget);
  });
}

class _FakeOpdsCatalogService extends OpdsCatalogService {
  final List<CatalogSource> catalogs;
  final Future<List<CatalogBook>> Function(CatalogSource catalog, String query)
  onSearch;

  _FakeOpdsCatalogService({required this.catalogs, required this.onSearch});

  @override
  Future<List<CatalogSource>> loadCatalogs() async => catalogs;

  @override
  Future<List<CatalogBook>> searchBooks(CatalogSource catalog, String query) =>
      onSearch(catalog, query);

  @override
  void dispose() {}
}
