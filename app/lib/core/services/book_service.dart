import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../formats/txt/txt_parser.dart';
import '../formats/cbz/cbz_parser.dart';
import '../formats/html/html_parser.dart';
import '../formats/pdf/pdf_parser.dart';
import '../models/models.dart';
import 'epub_service.dart';
import 'path_resolver.dart';

/// Unified service for importing and reading books of any supported format.
class BookService {
  static const _uuid = Uuid();
  final EpubService _epubService;

  BookService({EpubService? epubService})
    : _epubService = epubService ?? EpubService();

  EpubService get epubService => _epubService;

  /// Import a book file — auto-detects format from extension.
  Future<Book> importBook(String filePath) async {
    final format = BookFormat.fromExtension(filePath);
    return switch (format) {
      BookFormat.epub => _epubService.parseEpub(filePath),
      BookFormat.pdf => _importPdf(filePath),
      BookFormat.txt => _importTxt(filePath),
      BookFormat.cbz => _importCbz(filePath),
      BookFormat.html => _importHtml(filePath),
    };
  }

  // ── Chapter / content access ──────────────────────────────────────────────

  /// Get chapter list for any format.
  Future<List<ChapterInfo>> getChapters(
    String filePath,
    BookFormat format,
  ) async {
    return switch (format) {
      BookFormat.epub => _getEpubChapters(filePath),
      BookFormat.pdf => PdfParser.getChapters(filePath),
      BookFormat.txt => TxtParser.getChapters(filePath),
      BookFormat.cbz => CbzParser.getChapters(filePath),
      BookFormat.html => HtmlParser.getChapters(filePath),
    };
  }

  /// Get rendered content for a chapter (HTML string for WebView-based formats).
  Future<String> getChapterContent(
    String filePath,
    BookFormat format,
    int chapterIndex,
  ) async {
    return switch (format) {
      BookFormat.epub => _epubService.getChapterContent(filePath, chapterIndex),
      BookFormat.txt => TxtParser.getChapterContent(filePath, chapterIndex),
      BookFormat.html => HtmlParser.getChapterContent(filePath, chapterIndex),
      _ => '', // PDF and CBZ don't use HTML content
    };
  }

  /// Close a book (evict from cache).
  void closeBook(String filePath, BookFormat format) {
    if (format == BookFormat.epub) {
      _epubService.closeBook(filePath);
    }
    TxtParser.clearCache(filePath);
    HtmlParser.clearCache(filePath);
    CbzParser.clearCache(filePath);
  }

  // ── Private import methods ────────────────────────────────────────────────

  Future<Book> _importPdf(String filePath) async {
    final file = File(filePath);
    final bookId = _uuid.v4();
    final basePath = PathResolver.basePath;
    final booksDir = Directory(p.join(basePath, 'moku_books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final destPath = p.join(booksDir.path, '$bookId.pdf');
    await file.copy(destPath);

    final meta = await PdfParser.extractMetadata(filePath);

    return Book(
      id: bookId,
      title: meta.title ?? p.basenameWithoutExtension(filePath),
      author: meta.author ?? '',
      description: meta.subject,
      filePath: PathResolver.toRelative(destPath),
      format: BookFormat.pdf,
      totalChapters: meta.pageCount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<Book> _importTxt(String filePath) async {
    final file = File(filePath);
    final bookId = _uuid.v4();
    final basePath = PathResolver.basePath;
    final booksDir = Directory(p.join(basePath, 'moku_books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final destPath = p.join(booksDir.path, '$bookId.txt');
    await file.copy(destPath);

    final bytes = await file.readAsBytes();
    final meta = TxtParser.extractMetadata(bytes, filePath);

    return Book(
      id: bookId,
      title: meta.title,
      author: meta.author,
      filePath: PathResolver.toRelative(destPath),
      format: BookFormat.txt,
      totalChapters: meta.chapterCount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<Book> _importCbz(String filePath) async {
    final file = File(filePath);
    final bookId = _uuid.v4();
    final basePath = PathResolver.basePath;
    final booksDir = Directory(p.join(basePath, 'moku_books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final destPath = p.join(booksDir.path, '$bookId.cbz');
    await file.copy(destPath);

    final bytes = await file.readAsBytes();
    final meta = CbzParser.extractMetadata(bytes, filePath);

    // Extract first image as cover
    String? coverPath;
    try {
      final coverData = CbzParser.extractCover(bytes);
      if (coverData != null) {
        final coversDir = Directory(p.join(booksDir.path, 'covers'));
        if (!await coversDir.exists()) await coversDir.create(recursive: true);
        final coverFile = File(p.join(coversDir.path, '$bookId.jpg'));
        await coverFile.writeAsBytes(coverData);
        coverPath = PathResolver.toRelative(coverFile.path);
      }
    } catch (_) {}

    return Book(
      id: bookId,
      title: meta.title,
      author: meta.author,
      coverPath: coverPath,
      filePath: PathResolver.toRelative(destPath),
      format: BookFormat.cbz,
      totalChapters: meta.pageCount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<Book> _importHtml(String filePath) async {
    final file = File(filePath);
    final bookId = _uuid.v4();
    final basePath = PathResolver.basePath;
    final booksDir = Directory(p.join(basePath, 'moku_books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final ext = p.extension(filePath).toLowerCase();
    final destPath = p.join(booksDir.path, '$bookId$ext');
    await file.copy(destPath);

    final bytes = await file.readAsBytes();
    final meta = HtmlParser.extractMetadata(bytes, filePath);

    return Book(
      id: bookId,
      title: meta.title,
      author: meta.author,
      filePath: PathResolver.toRelative(destPath),
      format: BookFormat.html,
      totalChapters: meta.chapterCount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<ChapterInfo>> _getEpubChapters(String filePath) async {
    final chapters = await _epubService.getChapters(filePath);
    return chapters
        .map(
          (ch) => ChapterInfo(
            index: ch.index,
            title: ch.title,
            fileName: ch.fileName,
            fragment: ch.fragment,
          ),
        )
        .toList();
  }
}

/// Generic chapter info — format-agnostic.
class ChapterInfo {
  final int index;
  final String title;
  final String fileName;
  final String? fragment;

  const ChapterInfo({
    required this.index,
    required this.title,
    this.fileName = '',
    this.fragment,
  });
}
