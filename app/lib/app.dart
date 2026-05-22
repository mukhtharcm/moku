import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/database.dart';
import 'core/localization/app_locale_cubit.dart';
import 'core/services/book_service.dart';
import 'core/services/epub_service.dart';
import 'core/services/opds_catalog_service.dart';
import 'core/sync/auto_sync_service.dart';
import 'core/sync/sync_bootstrap.dart';
import 'core/sync/sync_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/library/cubit/library_cubit.dart';
import 'features/collections/cubit/collections_cubit.dart';
import 'features/search/cubit/search_cubit.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'l10n/l10n.dart';
import 'app_shell.dart';

class MokuApp extends StatelessWidget {
  final AppDatabase database;
  final BookService bookService;
  final EpubService epubService;
  final OpdsCatalogService opdsCatalogService;
  final bool showOnboarding;
  final AppLocaleCubit appLocaleCubit;
  final SyncConfigCubit syncConfigCubit;
  final AutoSyncService autoSyncService;
  final SyncBootstrap syncBootstrap;

  const MokuApp({
    super.key,
    required this.database,
    required this.bookService,
    required this.epubService,
    required this.opdsCatalogService,
    this.showOnboarding = false,
    required this.appLocaleCubit,
    required this.syncConfigCubit,
    required this.autoSyncService,
    required this.syncBootstrap,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: database),
        RepositoryProvider.value(value: bookService),
        RepositoryProvider.value(value: epubService),
        RepositoryProvider.value(value: opdsCatalogService),
        RepositoryProvider.value(value: autoSyncService),
        RepositoryProvider.value(value: syncBootstrap),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()..loadTheme()),
          BlocProvider.value(value: appLocaleCubit),
          BlocProvider(
            create: (ctx) => LibraryCubit(
              database: database,
              bookService: bookService,
              autoSync: autoSyncService,
            )..loadBooks(),
          ),
          BlocProvider(
            create: (_) =>
                CollectionsCubit(database: database, autoSync: autoSyncService)
                  ..loadCollections(),
          ),
          BlocProvider(
            create: (_) => SearchCubit(
              catalogService: opdsCatalogService,
              bookService: bookService,
              database: database,
            )..loadCatalogs(),
          ),
          BlocProvider.value(value: syncConfigCubit),
        ],
        child: BlocBuilder<AppLocaleCubit, AppLocaleState>(
          builder: (context, localeState) {
            return BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, themeState) {
                return MaterialApp(
                  onGenerateTitle: (context) => context.l10n.appTitle,
                  debugShowCheckedModeBanner: false,
                  locale: localeState.locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: MokuTheme.lightTheme(),
                  darkTheme: MokuTheme.darkTheme(),
                  themeMode: themeState.themeMode,
                  builder: (context, child) {
                    final themedChild = child ?? const SizedBox.shrink();
                    final direction = Directionality.maybeOf(context);
                    if (direction == null) {
                      return themedChild;
                    }

                    return Theme(
                      data: MokuTheme.adaptForTextDirection(
                        Theme.of(context),
                        direction,
                      ),
                      child: themedChild,
                    );
                  },
                  home: showOnboarding
                      ? const OnboardingScreen()
                      : const AppShell(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
