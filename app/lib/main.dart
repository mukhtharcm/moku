import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:window_manager/window_manager.dart';

import 'core/database/database.dart';
import 'core/localization/app_locale_cubit.dart';
import 'core/services/book_service.dart';
import 'core/services/epub_service.dart';
import 'core/services/opds_catalog_service.dart';
import 'core/services/path_resolver.dart';
import 'core/sync/auto_sync_service.dart';
import 'core/sync/sync_bootstrap.dart';
import 'core/sync/sync_config.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove the native title bar on desktop — window_manager takes over.
  // Must run before runApp; the window is hidden until show() is called
  // inside the callback, which prevents any flash of unstyled chrome.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows)) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(
      const WindowOptions(titleBarStyle: TitleBarStyle.hidden),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  // Initialize path resolver before anything touches file paths
  await PathResolver.init();

  final database = AppDatabase();
  final epubService = EpubService();
  final bookService = BookService(epubService: epubService);
  final opdsCatalogService = OpdsCatalogService();
  final appLocaleCubit = AppLocaleCubit();
  await appLocaleCubit.loadLocale();

  // ---- Sync stack -------------------------------------------------------
  // We construct these eagerly so auto-sync can run from launch without
  // requiring the user to visit the Settings screen first.
  final syncConfigCubit = SyncConfigCubit();
  await syncConfigCubit.loadConfig();

  final autoSyncService = AutoSyncService(configCubit: syncConfigCubit);
  final syncBootstrap = SyncBootstrap(
    database: database,
    configCubit: syncConfigCubit,
    autoSyncService: autoSyncService,
  );
  // Restore auth + construct shared SyncEngine in the background so app
  // startup isn't blocked by network.
  // ignore: unawaited_futures
  syncBootstrap.init();

  // Check if this is a first launch
  final needsOnboarding = !(await isOnboardingCompleted());

  runApp(
    MokuApp(
      database: database,
      bookService: bookService,
      epubService: epubService,
      opdsCatalogService: opdsCatalogService,
      showOnboarding: needsOnboarding,
      appLocaleCubit: appLocaleCubit,
      syncConfigCubit: syncConfigCubit,
      autoSyncService: autoSyncService,
      syncBootstrap: syncBootstrap,
    ),
  );
}
