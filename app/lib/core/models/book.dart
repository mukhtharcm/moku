import 'package:equatable/equatable.dart';

class Book extends Equatable {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String? coverPath;
  final String filePath;
  final String? isbn;
  final String? language;
  final String? publisher;
  final DateTime? publishDate;
  final int totalChapters;
  final String? fileHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? remoteId;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    this.coverPath,
    required this.filePath,
    this.isbn,
    this.language,
    this.publisher,
    this.publishDate,
    this.totalChapters = 0,
    this.fileHash,
    required this.createdAt,
    required this.updatedAt,
    this.remoteId,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    String? coverPath,
    String? filePath,
    String? isbn,
    String? language,
    String? publisher,
    DateTime? publishDate,
    int? totalChapters,
    String? fileHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? remoteId,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      isbn: isbn ?? this.isbn,
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      publishDate: publishDate ?? this.publishDate,
      totalChapters: totalChapters ?? this.totalChapters,
      fileHash: fileHash ?? this.fileHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    description,
    coverPath,
    filePath,
    isbn,
    language,
    publisher,
    publishDate,
    totalChapters,
    fileHash,
    createdAt,
    updatedAt,
    remoteId,
  ];
}
