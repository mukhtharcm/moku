import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../epub/moku_epub.dart';
import '../models/models.dart';

/// Cached representation of a parsed EPUB, keyed by file path.
class _CachedEpub {
  final EpubDocument document;
  final EpubContentServer contentServer;

  _CachedEpub({required this.document, required this.contentServer});
}

class EpubService {
  static const _uuid = Uuid();

  final Map<String, _CachedEpub> _cache = {};

  /// Parse an EPUB file and extract metadata + cover.
  Future<Book> parseEpub(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final doc = EpubParser.parse(bytes);
    final server = EpubContentServer(doc);

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'moku_books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final bookId = _uuid.v4();

    // Copy EPUB to app directory
    final destPath = p.join(booksDir.path, '$bookId.epub');
    await file.copy(destPath);

    // Extract cover image (save raw bytes — no transcoding needed)
    String? coverPath;
    try {
      coverPath = await _extractCover(server, booksDir.path, bookId);
    } catch (_) {
      // Cover extraction is optional
    }

    final meta = doc.metadata;
    final now = DateTime.now();

    return Book(
      id: bookId,
      title: meta.title,
      author: meta.authors.join(', '),
      description: meta.description,
      coverPath: coverPath,
      filePath: destPath,
      isbn: meta.isbn,
      language: meta.language,
      publisher: meta.publisher,
      totalChapters: server.chapters.length,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Open an EPUB for reading — caches the parsed content.
  Future<_CachedEpub> _openBook(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final doc = EpubParser.parse(bytes);
    final server = EpubContentServer(doc);

    final cached = _CachedEpub(document: doc, contentServer: server);
    _cache[filePath] = cached;
    return cached;
  }

  /// Evict a book from cache (call when closing the reader).
  void closeBook(String filePath) {
    _cache.remove(filePath);
  }

  /// Get the chapter list for the reader UI.
  Future<List<EpubChapterInfo>> getChapters(String filePath) async {
    final cached = await _openBook(filePath);
    return cached.contentServer.chapters
        .map((ch) => EpubChapterInfo(
              index: ch.index,
              title: ch.title,
              fileName: ch.contentHref,
              fragment: ch.fragment,
            ))
        .toList();
  }

  /// Get rendered HTML content for a chapter.
  Future<String> getChapterContent(String filePath, int chapterIndex) async {
    final cached = await _openBook(filePath);
    return cached.contentServer.getChapterContent(chapterIndex);
  }

  // --- Cover extraction ---

  Future<String?> _extractCover(
    EpubContentServer server,
    String directory,
    String bookId,
  ) async {
    final cover = server.getCoverImage();
    if (cover == null) return null;

    final coversDir = Directory(p.join(directory, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    // Determine file extension from media type
    final ext = switch (cover.mediaType) {
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/svg+xml' => 'svg',
      _ => 'jpg',
    };

    final coverPath = p.join(coversDir.path, '$bookId.$ext');
    await File(coverPath).writeAsBytes(cover.data);
    return coverPath;
  }
}

/// Chapter info exposed to the reader UI.
class EpubChapterInfo {
  final int index;
  final String title;
  final String fileName;
  final String? fragment;

  const EpubChapterInfo({
    required this.index,
    required this.title,
    required this.fileName,
    this.fragment,
  });
}
