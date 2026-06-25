import 'package:equatable/equatable.dart';

class UnsupportedBookFormat implements Exception {
  final String extension;

  const UnsupportedBookFormat(this.extension);
}

/// Supported book formats in Moku.
enum BookFormat {
  epub,
  pdf,
  txt,
  cbz,
  html;

  /// Detect format from file extension.
  static BookFormat fromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'epub' => BookFormat.epub,
      'pdf' => BookFormat.pdf,
      'txt' || 'text' => BookFormat.txt,
      'cbz' => BookFormat.cbz,
      'html' || 'htm' || 'xhtml' => BookFormat.html,
      _ => throw UnsupportedBookFormat(ext),
    };
  }

  /// File extensions accepted by the file picker for this format.
  static List<String> get allExtensions => [
    'epub',
    'pdf',
    'txt',
    'cbz',
    'html',
    'htm',
    'xhtml',
  ];
}

class Book extends Equatable {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String? coverPath;
  final String filePath;
  final BookFormat format;
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
    this.format = BookFormat.epub,
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
    BookFormat? format,
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
      format: format ?? this.format,
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
    format,
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
