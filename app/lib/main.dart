import 'package:flutter/material.dart';

import 'core/database/database.dart';
import 'core/services/book_service.dart';
import 'core/services/epub_service.dart';
import 'core/services/opds_catalog_service.dart';
import 'core/services/path_resolver.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize path resolver before anything touches file paths
  await PathResolver.init();

  final database = AppDatabase();
  final epubService = EpubService();
  final bookService = BookService(epubService: epubService);
  final opdsCatalogService = OpdsCatalogService();

  // Check if this is a first launch
  final needsOnboarding = !(await isOnboardingCompleted());

  runApp(
    MokuApp(
      database: database,
      bookService: bookService,
      epubService: epubService,
      opdsCatalogService: opdsCatalogService,
      showOnboarding: needsOnboarding,
    ),
  );
}
