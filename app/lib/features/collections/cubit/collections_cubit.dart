import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/models.dart';
import '../../../core/sync/auto_sync_service.dart';
import 'collections_state.dart';

class CollectionsCubit extends Cubit<CollectionsState> {
  final db.AppDatabase _database;
  final AutoSyncService? _autoSync;
  StreamSubscription? _subscription;
  static const _uuid = Uuid();

  CollectionsCubit({
    required db.AppDatabase database,
    AutoSyncService? autoSync,
  }) : _database = database,
       _autoSync = autoSync,
       super(const CollectionsState());

  void loadCollections() {
    emit(state.copyWith(status: CollectionsStatus.loading));
    _subscription?.cancel();
    _subscription = _database.watchAllCollections().listen(
      (dbCollections) {
        final collections = dbCollections
            .map(
              (c) => BookCollection(
                id: c.id,
                name: c.name,
                description: c.description,
                coverPath: c.coverPath,
                createdAt: c.createdAt,
                updatedAt: c.updatedAt,
                remoteId: c.remoteId,
              ),
            )
            .toList();
        emit(
          state.copyWith(
            status: CollectionsStatus.loaded,
            collections: collections,
          ),
        );
      },
      onError: (e) {
        emit(state.copyWith(status: CollectionsStatus.error));
      },
    );
  }

  Future<void> createCollection(String name, {String? description}) async {
    final now = DateTime.now();
    await _database.insertCollection(
      db.BookCollectionsCompanion.insert(
        id: _uuid.v4(),
        name: name,
        description: Value(description),
        createdAt: now,
        updatedAt: now,
      ),
    );
    _autoSync?.bump();
  }

  Future<void> deleteCollection(String id) async {
    await _database.softDeleteCollection(id);
    _autoSync?.bump();
    _autoSync?.flushNow();
  }

  void selectCollection(String? collectionId) {
    emit(state.copyWith(
      selectedCollectionId: collectionId,
      clearSelectedCollection: collectionId == null,
    ));
  }

  Future<void> addBookToCollection(String collectionId, String bookId) async {
    await _database.addBookToCollection(collectionId, bookId);
    _autoSync?.bump();
  }

  Future<void> removeBookFromCollection(
    String collectionId,
    String bookId,
  ) async {
    await _database.removeBookFromCollection(collectionId, bookId);
    _autoSync?.bump();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
