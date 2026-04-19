import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

class EpubService {
  static const _uuid = Uuid();

  /// Parse an EPUB file and extract metadata + cover
  Future<Book> parseEpub(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'moku_books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final bookId = _uuid.v4();

    // Copy epub to app directory
    final destPath = p.join(booksDir.path, '$bookId.epub');
    await file.copy(destPath);

    // Extract cover image
    String? coverPath;
    try {
      coverPath = await _extractCover(epubBook, booksDir.path, bookId);
    } catch (_) {
      // Cover extraction is optional
    }

    // Count chapters
    final chapters = epubBook.Chapters ?? [];
    int totalChapters = 0;
    for (final chapter in chapters) {
      totalChapters++;
      if (chapter.SubChapters != null) {
        totalChapters += chapter.SubChapters!.length;
      }
    }

    final now = DateTime.now();
    return Book(
      id: bookId,
      title: epubBook.Title ?? 'Unknown Title',
      author: epubBook.AuthorList?.join(', ') ?? 'Unknown Author',
      description: _extractDescription(epubBook),
      coverPath: coverPath,
      filePath: destPath,
      isbn: _extractIsbn(epubBook),
      language: epubBook.Schema?.Package?.Metadata?.Languages?.firstOrNull,
      publisher:
          epubBook.Schema?.Package?.Metadata?.Publishers?.firstOrNull,
      totalChapters: totalChapters,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get the list of chapters from an EPUB file
  Future<List<EpubChapterInfo>> getChapters(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final chapters = <EpubChapterInfo>[];
    final epubChapters = epubBook.Chapters ?? [];

    for (int i = 0; i < epubChapters.length; i++) {
      final chapter = epubChapters[i];
      chapters.add(EpubChapterInfo(
        index: i,
        title: chapter.Title ?? 'Chapter ${i + 1}',
        fileName: chapter.ContentFileName ?? '',
      ));
    }

    return chapters;
  }

  /// Get chapter HTML content by index
  Future<String> getChapterContent(String filePath, int chapterIndex) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final chapters = epubBook.Chapters ?? [];
    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      return '<p>Chapter not found</p>';
    }

    return chapters[chapterIndex].HtmlContent ?? '<p>No content</p>';
  }

  /// Get all content files (images, css, etc.) for the EPUB
  Future<Map<String, Uint8List>> getContentFiles(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final contentFiles = <String, Uint8List>{};
    final content = epubBook.Content;

    if (content?.Images != null) {
      for (final entry in content!.Images!.entries) {
        if (entry.value.Content != null) {
          contentFiles[entry.key] = Uint8List.fromList(entry.value.Content!);
        }
      }
    }

    if (content?.Css != null) {
      for (final entry in content!.Css!.entries) {
        if (entry.value.Content != null) {
          contentFiles[entry.key] =
              Uint8List.fromList(entry.value.Content!.codeUnits);
        }
      }
    }

    return contentFiles;
  }

  Future<String?> _extractCover(
    EpubBook epubBook,
    String directory,
    String bookId,
  ) async {
    final coverImage = epubBook.CoverImage;
    if (coverImage == null) return null;

    final coversDir = Directory(p.join(directory, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final coverPath = p.join(coversDir.path, '$bookId.jpg');

    // Encode image to JPEG
    final encoded = img.encodeJpg(coverImage, quality: 85);
    await File(coverPath).writeAsBytes(encoded);

    return coverPath;
  }

  String? _extractDescription(EpubBook epubBook) {
    return epubBook.Schema?.Package?.Metadata?.Description;
  }

  String? _extractIsbn(EpubBook epubBook) {
    final identifiers =
        epubBook.Schema?.Package?.Metadata?.Identifiers;
    if (identifiers != null) {
      for (final id in identifiers) {
        if (id.Scheme?.toLowerCase() == 'isbn' || id.Id?.toLowerCase() == 'isbn') {
          return id.Identifier;
        }
      }
    }
    return null;
  }
}

class EpubChapterInfo {
  final int index;
  final String title;
  final String fileName;

  const EpubChapterInfo({
    required this.index,
    required this.title,
    required this.fileName,
  });
}
