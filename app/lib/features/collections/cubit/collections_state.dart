import 'package:equatable/equatable.dart';
import '../../../core/models/models.dart';

enum CollectionsStatus { initial, loading, loaded, error }

class CollectionsState extends Equatable {
  final CollectionsStatus status;
  final List<BookCollection> collections;
  final String? errorMessage;

  const CollectionsState({
    this.status = CollectionsStatus.initial,
    this.collections = const [],
    this.errorMessage,
  });

  CollectionsState copyWith({
    CollectionsStatus? status,
    List<BookCollection>? collections,
    String? errorMessage,
  }) {
    return CollectionsState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, collections, errorMessage];
}
