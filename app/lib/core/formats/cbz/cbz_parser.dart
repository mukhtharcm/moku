import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../services/book_service.dart';

/// Metadata extracted from a CBZ (Comic Book ZIP) file.
class CbzMetadata {
  final String title;
  final String author;
  final int pageCount;

  const CbzMetadata({
    required this.title,
    required this.author,
    required this.pageCount,
  });
}

/// Cached CBZ data — sorted image file names + archive bytes.
class _CachedCbz {
  final List<ArchiveFile> images;
  final Archive archive;

  const _CachedCbz({required this.images, required this.archive});
}

/// Parser for CBZ (Comic Book ZIP) files.
///
/// CBZ files are ZIP archives containing sequentially-named image files.
/// Each image is one "page" of the comic.
class CbzParser {
  static final _cache = <String, _CachedCbz>{};

  static const _imageExtensions = {
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff',
  };

  /// Extract metadata from a CBZ file.
  static CbzMetadata extractMetadata(Uint8List bytes, String filePath) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final images = _getSortedImages(archive);

    return CbzMetadata(
      title: p.basenameWithoutExtension(filePath),
      author: 'Unknown',
      pageCount: images.length,
    );
  }

  /// Extract the first image as cover art.
  static Uint8List? extractCover(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final images = _getSortedImages(archive);
    if (images.isEmpty) return null;
    final content = images.first.content as List<int>;
    return Uint8List.fromList(content);
  }

  /// Get chapter (page) list for reader UI.
  static Future<List<ChapterInfo>> getChapters(String filePath) async {
    final cached = await _loadCbz(filePath);
    return cached.images.asMap().entries.map((e) {
      return ChapterInfo(index: e.key, title: 'Page ${e.key + 1}');
    }).toList();
  }

  /// Get a single page image as bytes.
  static Future<Uint8List> getPageImage(
      String filePath, int pageIndex) async {
    final cached = await _loadCbz(filePath);
    if (pageIndex < 0 || pageIndex >= cached.images.length) {
      return Uint8List(0);
    }
    final content = cached.images[pageIndex].content as List<int>;
    return Uint8List.fromList(content);
  }

  /// Get the media type of a page image.
  static String getMediaType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return switch (ext) {
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }

  /// Total page count for a cached CBZ.
  static Future<int> getPageCount(String filePath) async {
    final cached = await _loadCbz(filePath);
    return cached.images.length;
  }

  static void clearCache(String filePath) => _cache.remove(filePath);

  // ── Private ───────────────────────────────────────────────────────────────

  static Future<_CachedCbz> _loadCbz(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final images = _getSortedImages(archive);
    final cached = _CachedCbz(images: images, archive: archive);
    _cache[filePath] = cached;
    return cached;
  }

  /// Get image files from archive, sorted by filename (natural order).
  static List<ArchiveFile> _getSortedImages(Archive archive) {
    return archive.files
        .where((f) =>
            !f.isFile ? false : _isImageFile(f.name) && !_isHidden(f.name))
        .toList()
      ..sort((a, b) => _naturalCompare(a.name, b.name));
  }

  static bool _isImageFile(String name) {
    final ext = p.extension(name).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  static bool _isHidden(String name) {
    return p.basename(name).startsWith('.') ||
        name.contains('__MACOSX') ||
        name.contains('.DS_Store');
  }

  /// Natural sort comparison — handles "page2" vs "page10" correctly.
  static int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)');
    final aName = p.basename(a);
    final bName = p.basename(b);

    final aMatches = regExp.allMatches(aName).toList();
    final bMatches = regExp.allMatches(bName).toList();

    if (aMatches.isNotEmpty && bMatches.isNotEmpty) {
      // Compare by first number found in filename
      final aNum = int.parse(aMatches.first.group(0)!);
      final bNum = int.parse(bMatches.first.group(0)!);
      if (aNum != bNum) return aNum.compareTo(bNum);
    }

    return aName.compareTo(bName);
  }
}
