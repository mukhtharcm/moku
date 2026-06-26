// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart';
import 'package:moku/core/database/database.dart' as db;
import 'package:moku/core/models/models.dart';
import 'package:moku/core/services/path_resolver.dart';
import 'package:moku/features/collections/cubit/collections_cubit.dart';
import 'package:moku/features/collections/screens/collection_detail_screen.dart';
import 'package:moku/features/collections/screens/collections_screen.dart';
import 'package:moku/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const fontAssets = [
    'google_fonts/InstrumentSerif-Regular.ttf',
    'google_fonts/DMSans-Regular.ttf',
    'google_fonts/DMSans-Medium.ttf',
    'google_fonts/DMSans-SemiBold.ttf',
    'google_fonts/DMSans-Bold.ttf',
    'google_fonts/Literata-Bold.ttf',
  ];

  late Directory tempDir;
  late Uint8List fontBytes;
  late String coverPath;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tempDir = await Directory.systemTemp.createTemp('moku_test');
    fontBytes = await _loadTestFontBytes();
    coverPath = '${tempDir.path}/cover.png';
    await File(coverPath).writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9l9tAAAAAASUVORK5CYII=',
      ),
    );
    assetManifest = _TestAssetManifest(fontAssets);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
          switch (methodCall.method) {
            case 'getTemporaryDirectory':
            case 'getApplicationSupportDirectory':
            case 'getLibraryDirectory':
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationCacheDirectory':
            case 'getDownloadsDirectory':
            case 'getExternalStorageDirectory':
              return tempDir.path;
            case 'getExternalCacheDirectories':
            case 'getExternalStorageDirectories':
              return <String>[tempDir.path];
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final assetKey = utf8.decode(message!.buffer.asUint8List());
          if (fontAssets.contains(assetKey)) {
            return ByteData.sublistView(Uint8List.fromList(fontBytes));
          }
          return null;
        });
    await PathResolver.init();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'shelf rows expose a labeled delete action instead of an ambiguous overflow action',
    (tester) async {
      final database = db.AppDatabase(NativeDatabase.memory());
      final cubit = CollectionsCubit(database: database)..loadCollections();
      addTearDown(() async {
        await database.close();
        await cubit.close();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
      });

      final now = DateTime(2026);
      await database.insertCollection(
        db.BookCollectionsCompanion.insert(
          id: 'favorites',
          name: 'Favorites',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _pumpCollectionsScreen(tester, database: database, cubit: cubit);

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.byTooltip('Delete Shelf'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    },
  );

  testWidgets('empty shelf detail shows one add-books action', (tester) async {
    final database = _FakeCollectionDetailDatabase();
    addTearDown(() async {
      await database.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    });

    await _pumpCollectionDetailScreen(
      tester,
      database: database,
      collection: _testCollection(),
    );

    expect(find.text('Add Books'), findsOneWidget);
    expect(find.byTooltip('Add books'), findsNothing);
  });

  testWidgets('empty shelves screen shows one create action', (tester) async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final cubit = CollectionsCubit(database: database)..loadCollections();
    addTearDown(() async {
      await database.close();
      await cubit.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    });

    await _pumpCollectionsScreen(tester, database: database, cubit: cubit);

    expect(find.text('Create Shelf'), findsOneWidget);
    expect(find.byTooltip('Create Shelf'), findsNothing);
  });

  testWidgets(
    'add-books sheet lets users add a book by tapping the labeled row content',
    (tester) async {
      final database = _FakeCollectionDetailDatabase(
        libraryBooks: [
          _testDbBook(
            id: 'harbor-notes',
            title: 'Harbor Notes',
            author: 'Jane Doe',
            coverPath: coverPath,
          ),
        ],
      );
      addTearDown(() async {
        await database.close();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
      });

      await _pumpCollectionDetailScreen(
        tester,
        database: database,
        collection: _testCollection(),
      );

      await tester.tap(find.text('Add Books'));
      await tester.pumpAndSettle();

      expect(find.text('Harbor Notes'), findsOneWidget);
      await tester.tap(find.text('Harbor Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Added "Harbor Notes"'), findsOneWidget);
      expect(find.byTooltip('Add books'), findsOneWidget);
    },
  );
}

Future<void> _settleGoogleFonts(WidgetTester tester) async {
  await GoogleFonts.pendingFonts([
    GoogleFonts.instrumentSerif(),
    GoogleFonts.dmSans(),
    GoogleFonts.dmSans(fontWeight: FontWeight.w500),
    GoogleFonts.dmSans(fontWeight: FontWeight.w600),
    GoogleFonts.dmSans(fontWeight: FontWeight.w700),
    GoogleFonts.literata(fontWeight: FontWeight.w700),
  ]);
  await tester.pumpAndSettle();
}

Future<Uint8List> _loadTestFontBytes() async {
  const candidatePaths = [
    '/System/Library/Fonts/SFNS.ttf',
    '/System/Library/Fonts/SFNSMono.ttf',
    '/Library/Fonts/Arial Unicode.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
  ];

  for (final path in candidatePaths) {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsBytes();
    }
  }

  throw StateError('No usable test font found on this machine.');
}

Future<void> _pumpCollectionsScreen(
  WidgetTester tester, {
  required db.AppDatabase database,
  required CollectionsCubit cubit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepositoryProvider.value(
        value: database,
        child: BlocProvider.value(
          value: cubit,
          child: const CollectionsScreen(),
        ),
      ),
    ),
  );

  await _settleGoogleFonts(tester);
}

Future<void> _pumpCollectionDetailScreen(
  WidgetTester tester, {
  required db.AppDatabase database,
  required BookCollection collection,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepositoryProvider.value(
        value: database,
        child: CollectionDetailScreen(collection: collection),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

BookCollection _testCollection() {
  final now = DateTime(2026);
  return BookCollection(
    id: 'favorites',
    name: 'Favorites',
    createdAt: now,
    updatedAt: now,
  );
}

db.Book _testDbBook({
  required String id,
  required String title,
  required String author,
  String? coverPath,
}) {
  final now = DateTime(2026);
  return db.Book(
    id: id,
    title: title,
    author: author,
    coverPath: coverPath,
    filePath: 'moku_books/$id.epub',
    format: 'epub',
    totalChapters: 0,
    createdAt: now,
    updatedAt: now,
    syncPending: false,
  );
}

class _TestAssetManifest implements AssetManifest {
  _TestAssetManifest(this.assets);

  final List<String> assets;

  @override
  List<String> listAssets() => assets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

class _FakeCollectionDetailDatabase extends db.AppDatabase {
  _FakeCollectionDetailDatabase({
    List<db.Book> libraryBooks = const [],
    List<db.Book> collectionBooks = const [],
  }) : _libraryBooks = List.of(libraryBooks),
       _collectionBooks = List.of(collectionBooks),
       super(NativeDatabase.memory());

  final List<db.Book> _libraryBooks;
  final List<db.Book> _collectionBooks;
  final StreamController<List<db.Book>> _updates =
      StreamController<List<db.Book>>.broadcast();

  @override
  Future<List<db.Book>> getAllBooks({bool includeDeleted = false}) async =>
      List.of(_libraryBooks);

  @override
  Future<List<db.Book>> getBooksInCollection(String collectionId) async =>
      List.of(_collectionBooks);

  @override
  Stream<List<db.Book>> watchBooksInCollection(String collectionId) async* {
    yield List.of(_collectionBooks);
    yield* _updates.stream;
  }

  @override
  Future<void> addBookToCollection(
    String collectionId,
    String bookId, {
    bool markPending = true,
  }) async {
    final book = _libraryBooks.firstWhere(
      (candidate) => candidate.id == bookId,
    );
    _collectionBooks.add(book);
    _updates.add(List.of(_collectionBooks));
  }

  @override
  Future<void> close() async {
    await _updates.close();
    await super.close();
  }
}
