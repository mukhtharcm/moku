import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/database.dart';
import 'core/services/book_service.dart';
import 'core/services/epub_service.dart';
import 'core/services/open_library_service.dart';
import 'core/sync/sync_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/library/cubit/library_cubit.dart';
import 'features/collections/cubit/collections_cubit.dart';
import 'features/search/cubit/search_cubit.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'app_shell.dart';

class MokuApp extends StatelessWidget {
  final AppDatabase database;
  final BookService bookService;
  final EpubService epubService;
  final OpenLibraryService openLibraryService;
  final bool showOnboarding;

  const MokuApp({
    super.key,
    required this.database,
    required this.bookService,
    required this.epubService,
    required this.openLibraryService,
    this.showOnboarding = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: database),
        RepositoryProvider.value(value: bookService),
        RepositoryProvider.value(value: epubService),
        RepositoryProvider.value(value: openLibraryService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ThemeCubit()..loadTheme(),
          ),
          BlocProvider(
            create: (ctx) => LibraryCubit(
              database: database,
              bookService: bookService,
            )..loadBooks(),
          ),
          BlocProvider(
            create: (_) => CollectionsCubit(database: database)
              ..loadCollections(),
          ),
          BlocProvider(
            create: (_) => SearchCubit(
              openLibraryService: openLibraryService,
            ),
          ),
          BlocProvider(
            create: (_) => SyncConfigCubit()..loadConfig(),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              title: 'Moku',
              debugShowCheckedModeBanner: false,
              theme: MokuTheme.lightTheme(),
              darkTheme: MokuTheme.darkTheme(),
              themeMode: themeState.themeMode,
              home: showOnboarding
                  ? const OnboardingScreen()
                  : const AppShell(),
            );
          },
        ),
      ),
    );
  }
}
