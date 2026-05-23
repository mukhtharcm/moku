import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/features/library/cubit/library_cubit.dart';
import 'package:moku/features/library/cubit/library_state.dart';
import 'package:moku/features/library/screens/library_screen.dart';
import 'package:moku/l10n/l10n.dart';

class TestLibraryCubit extends Cubit<LibraryState> implements LibraryCubit {
  TestLibraryCubit({
    LibraryState initialState = const LibraryState(
      status: LibraryStatus.loaded,
    ),
  }) : super(initialState);

  @override
  Future<void> deleteBook(String bookId) async {}

  @override
  Future<void> importBook() async {}

  @override
  void loadBooks() {}

  @override
  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  @override
  void setSortMode(LibrarySortMode mode) {
    emit(state.copyWith(sortMode: mode));
  }

  @override
  void toggleViewMode() {
    final nextMode = state.viewMode == LibraryView.grid
        ? LibraryView.list
        : LibraryView.grid;
    emit(state.copyWith(viewMode: nextMode));
  }
}

Widget _buildLibraryScreen({
  required TestLibraryCubit cubit,
  required Locale locale,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<LibraryCubit>.value(
      value: cubit,
      child: const LibraryScreen(),
    ),
  );
}

void main() {
  testWidgets('Library header actions expose localized labels in English', (
    WidgetTester tester,
  ) async {
    final cubit = TestLibraryCubit();
    final semantics = tester.ensureSemantics();
    addTearDown(cubit.close);
    try {
      await tester.pumpWidget(
        _buildLibraryScreen(cubit: cubit, locale: const Locale('en')),
      );
      await tester.pump();

      final searchButton = find.widgetWithIcon(
        IconButton,
        Icons.search_rounded,
      );
      final listViewButton = find.widgetWithIcon(
        IconButton,
        Icons.view_list_rounded,
      );

      expect(find.byTooltip('Search library'), findsOneWidget);
      expect(
        tester.getSemantics(searchButton),
        matchesSemantics(
          label: 'Search library',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
      expect(find.byTooltip('Switch to list view'), findsOneWidget);
      expect(
        tester.getSemantics(listViewButton),
        matchesSemantics(
          label: 'Switch to list view',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(searchButton);
      await tester.pump();
      expect(find.byTooltip('Close search'), findsOneWidget);
      expect(
        tester.getSemantics(find.widgetWithIcon(IconButton, Icons.close)),
        matchesSemantics(
          label: 'Close search',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(listViewButton);
      await tester.pump();
      expect(find.byTooltip('Switch to grid view'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.widgetWithIcon(IconButton, Icons.grid_view_rounded),
        ),
        matchesSemantics(
          label: 'Switch to grid view',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Library header actions expose localized labels in Arabic', (
    WidgetTester tester,
  ) async {
    final cubit = TestLibraryCubit();
    final semantics = tester.ensureSemantics();
    addTearDown(cubit.close);
    try {
      await tester.pumpWidget(
        _buildLibraryScreen(cubit: cubit, locale: const Locale('ar')),
      );
      await tester.pump();

      final searchButton = find.widgetWithIcon(
        IconButton,
        Icons.search_rounded,
      );
      final listViewButton = find.widgetWithIcon(
        IconButton,
        Icons.view_list_rounded,
      );

      expect(find.byTooltip('ابحث في المكتبة'), findsOneWidget);
      expect(
        tester.getSemantics(searchButton),
        matchesSemantics(
          label: 'ابحث في المكتبة',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
      expect(find.byTooltip('التبديل إلى عرض القائمة'), findsOneWidget);
      expect(
        tester.getSemantics(listViewButton),
        matchesSemantics(
          label: 'التبديل إلى عرض القائمة',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(searchButton);
      await tester.pump();
      expect(find.byTooltip('إغلاق البحث'), findsOneWidget);
      expect(
        tester.getSemantics(find.widgetWithIcon(IconButton, Icons.close)),
        matchesSemantics(
          label: 'إغلاق البحث',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(listViewButton);
      await tester.pump();
      expect(find.byTooltip('التبديل إلى عرض الشبكة'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.widgetWithIcon(IconButton, Icons.grid_view_rounded),
        ),
        matchesSemantics(
          label: 'التبديل إلى عرض الشبكة',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
