import 'package:flutter/material.dart';

import 'core/database/database.dart';
import 'core/services/epub_service.dart';
import 'core/services/open_library_service.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final epubService = EpubService();
  final openLibraryService = OpenLibraryService();

  runApp(MokuApp(
    database: database,
    epubService: epubService,
    openLibraryService: openLibraryService,
  ));
}
