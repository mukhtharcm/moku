import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/database/database.dart';
import 'package:moku/core/sync/auth_service.dart';
import 'package:moku/core/sync/auto_sync_service.dart';
import 'package:moku/core/sync/sync_bootstrap.dart';
import 'package:moku/core/sync/sync_config.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({required this.currentUserId});

  final String currentUserId;

  @override
  PocketBase? get pb => null;

  @override
  bool get isAuthenticated => true;

  @override
  String? get userId => currentUserId;

  @override
  Future<void> init(String serverUrl) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SyncConfigCubit configCubit;
  late AutoSyncService autoSyncService;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sync_server_url': 'http://10.0.2.2:8090',
      'sync_is_enabled': true,
      'sync_last_sync_at': DateTime.utc(2026, 5, 24, 10).millisecondsSinceEpoch,
      'sync_last_identity': 'http://10.0.2.2:8090::old-user',
    });
    database = AppDatabase(NativeDatabase.memory());
    configCubit = SyncConfigCubit();
    autoSyncService = AutoSyncService(configCubit: configCubit);
  });

  tearDown(() async {
    await database.close();
    await configCubit.close();
  });

  test('onAuthenticated resets local sync content when identity changes', () async {
    await configCubit.loadConfig();
    final tempDir = await Directory.systemTemp.createTemp('moku-sync-identity');
    final bookFile = File('${tempDir.path}/book.epub')..writeAsStringSync('book');
    final coverFile = File('${tempDir.path}/cover.png')..writeAsStringSync('cover');
    final collectionCover = File('${tempDir.path}/collection.png')
      ..writeAsStringSync('collection');
    final now = DateTime.utc(2026, 5, 24, 10);

    await database.insertBook(
      BooksCompanion.insert(
        id: 'book-1',
        title: 'Book',
        author: 'Author',
        filePath: bookFile.path,
        coverPath: Value(coverFile.path),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.insertCollection(
      BookCollectionsCompanion.insert(
        id: 'collection-1',
        name: 'Shelf',
        coverPath: Value(collectionCover.path),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.upsertGoal(
      ReadingGoalsCompanion.insert(
        id: 'goal-1',
        year: 2026,
        updatedAt: Value(now),
      ),
    );

    final bootstrap = SyncBootstrap(
      database: database,
      configCubit: configCubit,
      autoSyncService: autoSyncService,
      authService: FakeAuthService(currentUserId: 'new-user'),
    );

    await bootstrap.onAuthenticated();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('sync_last_identity'),
      'http://10.0.2.2:8090::new-user',
    );
    expect(prefs.getInt('sync_last_sync_at'), isNull);
    expect(configCubit.state.config.lastSyncAt, isNull);
    expect(await database.getAllBooks(includeDeleted: true), isEmpty);
    expect(await database.getAllCollections(includeDeleted: true), isEmpty);
    expect(await database.getAllGoals(includeDeleted: true), isEmpty);
    expect(await bookFile.exists(), isFalse);
    expect(await coverFile.exists(), isFalse);
    expect(await collectionCover.exists(), isFalse);

    await tempDir.delete(recursive: true);
  });

  test('onAuthenticated preserves local content for the same identity', () async {
    SharedPreferences.setMockInitialValues({
      'sync_server_url': 'http://10.0.2.2:8090',
      'sync_is_enabled': true,
      'sync_last_identity': 'http://10.0.2.2:8090::same-user',
    });
    await configCubit.loadConfig();
    final now = DateTime.utc(2026, 5, 24, 10);

    await database.insertBook(
      BooksCompanion.insert(
        id: 'book-1',
        title: 'Book',
        author: 'Author',
        filePath: '/tmp/book.epub',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final bootstrap = SyncBootstrap(
      database: database,
      configCubit: configCubit,
      autoSyncService: autoSyncService,
      authService: FakeAuthService(currentUserId: 'same-user'),
    );

    await bootstrap.onAuthenticated();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('sync_last_identity'),
      'http://10.0.2.2:8090::same-user',
    );
    expect(await database.getAllBooks(), hasLength(1));
  });
}
