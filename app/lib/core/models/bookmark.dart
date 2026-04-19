import 'package:equatable/equatable.dart';

class Bookmark extends Equatable {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String? cfi; // EPUB CFI for precise position
  final String title;
  final DateTime createdAt;
  final String? remoteId;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    this.cfi,
    required this.title,
    required this.createdAt,
    this.remoteId,
  });

  Bookmark copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? cfi,
    String? title,
    DateTime? createdAt,
    String? remoteId,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      cfi: cfi ?? this.cfi,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    bookId,
    chapterIndex,
    cfi,
    title,
    createdAt,
    remoteId,
  ];
}
