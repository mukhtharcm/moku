import 'package:equatable/equatable.dart';

class Highlight extends Equatable {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String? startCfi;
  final String? endCfi;
  final String selectedText;
  final String color; // hex color
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? remoteId;

  const Highlight({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    this.startCfi,
    this.endCfi,
    required this.selectedText,
    this.color = '#FFEB3B',
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.remoteId,
  });

  Highlight copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? startCfi,
    String? endCfi,
    String? selectedText,
    String? color,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? remoteId,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      startCfi: startCfi ?? this.startCfi,
      endCfi: endCfi ?? this.endCfi,
      selectedText: selectedText ?? this.selectedText,
      color: color ?? this.color,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    bookId,
    chapterIndex,
    startCfi,
    endCfi,
    selectedText,
    color,
    note,
    createdAt,
    updatedAt,
    remoteId,
  ];
}
