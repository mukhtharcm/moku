import 'package:equatable/equatable.dart';

class BookCollection extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? remoteId;

  const BookCollection({
    required this.id,
    required this.name,
    this.description,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
    this.remoteId,
  });

  BookCollection copyWith({
    String? id,
    String? name,
    String? description,
    String? coverPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? remoteId,
  }) {
    return BookCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    coverPath,
    createdAt,
    updatedAt,
    remoteId,
  ];
}
