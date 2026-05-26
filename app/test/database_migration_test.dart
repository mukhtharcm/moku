import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('repairs mixed legacy schemas during upgrade', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'moku_database_migration_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final dbFile = File('${tempDir.path}/moku_db.sqlite');
    final legacyDb = sqlite.sqlite3.open(dbFile.path);

    legacyDb.execute('PRAGMA user_version = 2;');
    legacyDb.execute('''
      CREATE TABLE books (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        description TEXT,
        cover_path TEXT,
        file_path TEXT NOT NULL,
        format TEXT NOT NULL DEFAULT 'epub',
        isbn TEXT,
        language TEXT,
        publisher TEXT,
        publish_date INTEGER,
        total_chapters INTEGER NOT NULL DEFAULT 0,
        file_hash TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        remote_id TEXT,
        deleted_at INTEGER
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE reading_progresses (
        id TEXT NOT NULL PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books (id),
        current_chapter INTEGER NOT NULL DEFAULT 0,
        chapter_progress REAL NOT NULL DEFAULT 0.0,
        overall_progress REAL NOT NULL DEFAULT 0.0,
        last_position TEXT,
        last_read_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        remote_id TEXT,
        deleted_at INTEGER
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE bookmarks (
        id TEXT NOT NULL PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books (id),
        chapter_index INTEGER NOT NULL,
        cfi TEXT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        remote_id TEXT,
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        deleted_at INTEGER
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE highlights (
        id TEXT NOT NULL PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books (id),
        chapter_index INTEGER NOT NULL,
        start_cfi TEXT,
        end_cfi TEXT,
        selected_text TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#FFEB3B',
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        remote_id TEXT,
        deleted_at INTEGER
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE book_collections (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        cover_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        remote_id TEXT,
        deleted_at INTEGER
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE collection_books (
        collection_id TEXT NOT NULL REFERENCES book_collections (id),
        book_id TEXT NOT NULL REFERENCES books (id),
        sort_order INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT,
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        deleted_at INTEGER,
        PRIMARY KEY (collection_id, book_id)
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE reading_sessions (
        id TEXT NOT NULL PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books (id) ON DELETE CASCADE,
        book_title TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        start_chapter INTEGER NOT NULL DEFAULT 0,
        end_chapter INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        deleted_at INTEGER,
        sync_pending INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE reading_goals (
        id TEXT NOT NULL PRIMARY KEY,
        year INTEGER NOT NULL UNIQUE,
        books_goal INTEGER NOT NULL DEFAULT 12,
        minutes_per_day_goal INTEGER NOT NULL DEFAULT 30,
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        deleted_at INTEGER,
        sync_pending INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT
      );
    ''');

    legacyDb.execute('''
      INSERT INTO books (
        id,
        title,
        author,
        file_path,
        created_at,
        updated_at
      ) VALUES (
        'book-1',
        'Seed Book',
        'Author',
        '/tmp/book.epub',
        1716544800,
        1716544800
      );
    ''');
    legacyDb.execute('''
      INSERT INTO book_collections (
        id,
        name,
        created_at,
        updated_at
      ) VALUES (
        'collection-1',
        'Shelf',
        1716544800,
        1716544800
      );
    ''');
    legacyDb.dispose();

    final database = AppDatabase(NativeDatabase(dbFile));

    final books = await database.getAllBooks();
    final collections = await database.getAllCollections();
    final sessions = await database.getAllSessions();
    final goals = await database.getAllGoals();

    expect(books, hasLength(1));
    expect(books.single.syncPending, isFalse);
    expect(collections, hasLength(1));
    expect(collections.single.syncPending, isFalse);
    expect(sessions, isEmpty);
    expect(goals, isEmpty);

    await database.close();

    final repairedDb = sqlite.sqlite3.open(dbFile.path);
    addTearDown(repairedDb.dispose);

    expect(_userVersion(repairedDb), 7);
    expect(_hasColumn(repairedDb, 'books', 'sync_pending'), isTrue);
    expect(
      _hasColumn(repairedDb, 'reading_progresses', 'sync_pending'),
      isTrue,
    );
    expect(_hasColumn(repairedDb, 'bookmarks', 'sync_pending'), isTrue);
    expect(_hasColumn(repairedDb, 'highlights', 'sync_pending'), isTrue);
    expect(_hasColumn(repairedDb, 'book_collections', 'sync_pending'), isTrue);
    expect(_hasColumn(repairedDb, 'collection_books', 'sync_pending'), isTrue);
  });
}

bool _hasColumn(sqlite.Database db, String tableName, String columnName) {
  final rows = db.select('PRAGMA table_info($tableName)');
  return rows.any((row) => row['name'] == columnName);
}

int _userVersion(sqlite.Database db) {
  final rows = db.select('PRAGMA user_version');
  return rows.single.columnAt(0) as int;
}
