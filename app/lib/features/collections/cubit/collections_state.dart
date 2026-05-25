import 'package:equatable/equatable.dart';
import '../../../core/models/models.dart';

enum CollectionsStatus { initial, loading, loaded, error }

class CollectionsState extends Equatable {
  final CollectionsStatus status;
  final List<BookCollection> collections;
  final String? errorMessage;
  final String? selectedCollectionId;

  const CollectionsState({
    this.status = CollectionsStatus.initial,
    this.collections = const [],
    this.errorMessage,
    this.selectedCollectionId,
  });

  CollectionsState copyWith({
    CollectionsStatus? status,
    List<BookCollection>? collections,
    String? errorMessage,
    String? selectedCollectionId,
    bool clearSelectedCollection = false,
  }) {
    return CollectionsState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedCollectionId: clearSelectedCollection
          ? null
          : (selectedCollectionId ?? this.selectedCollectionId),
    );
  }

  BookCollection? get selectedCollection {
    if (selectedCollectionId == null) return null;
    try {
      return collections.firstWhere((c) => c.id == selectedCollectionId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props =>
      [status, collections, errorMessage, selectedCollectionId];
}
