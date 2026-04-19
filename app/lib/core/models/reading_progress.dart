import 'package:equatable/equatable.dart';

class ReadingProgress extends Equatable {
  final String id;
  final String bookId;
  final int currentChapter;
  final double chapterProgress;
  final double overallProgress;
  final String? lastPosition; // JSON string for detailed position
  final DateTime lastReadAt;
  final DateTime updatedAt;
  final String? remoteId;

  const ReadingProgress({
    required this.id,
    required this.bookId,
    this.currentChapter = 0,
    this.chapterProgress = 0.0,
    this.overallProgress = 0.0,
    this.lastPosition,
    required this.lastReadAt,
    required this.updatedAt,
    this.remoteId,
  });

  ReadingProgress copyWith({
    String? id,
    String? bookId,
    int? currentChapter,
    double? chapterProgress,
    double? overallProgress,
    String? lastPosition,
    DateTime? lastReadAt,
    DateTime? updatedAt,
    String? remoteId,
  }) {
    return ReadingProgress(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      currentChapter: currentChapter ?? this.currentChapter,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      overallProgress: overallProgress ?? this.overallProgress,
      lastPosition: lastPosition ?? this.lastPosition,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    bookId,
    currentChapter,
    chapterProgress,
    overallProgress,
    lastPosition,
    lastReadAt,
    updatedAt,
    remoteId,
  ];
}
