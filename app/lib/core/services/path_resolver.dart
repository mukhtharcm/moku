import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves stored file paths that may become invalid when the iOS sandbox
/// UUID changes (e.g. after reinstall or clean build).
///
/// Call [init] once at app startup. Then use [resolve] to turn any stored path
/// (absolute or relative) into a valid absolute path.
class PathResolver {
  static String? _basePath;

  /// Must be called before any [resolve] calls — typically in main().
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _basePath = dir.path;
  }

  /// Current documents directory path.
  static String get basePath {
    assert(_basePath != null, 'PathResolver.init() must be called first');
    return _basePath!;
  }

  /// Convert a stored path (absolute or relative) to a valid absolute path.
  ///
  /// - Relative paths (e.g. `moku_books/abc.epub`) are resolved against the
  ///   current documents directory.
  /// - Absolute paths that still exist are returned as-is.
  /// - Absolute paths that no longer exist (stale sandbox UUID) are
  ///   re-resolved by extracting the relative portion after `moku_books/`.
  static String resolve(String storedPath) {
    if (_basePath == null) {
      throw StateError('PathResolver.init() must be called before resolve()');
    }

    // Relative path — just join with base
    if (!storedPath.startsWith('/')) {
      return p.join(_basePath!, storedPath);
    }

    // Absolute path that still exists — fast path
    if (File(storedPath).existsSync()) {
      return storedPath;
    }

    // Stale absolute path — try to extract the moku_books-relative portion
    final idx = storedPath.indexOf('moku_books/');
    if (idx >= 0) {
      return p.join(_basePath!, storedPath.substring(idx));
    }

    // Fall back to returning the original (caller will get a FileNotFound)
    return storedPath;
  }

  /// Same as [resolve] but accepts null.
  static String? resolveNullable(String? storedPath) {
    if (storedPath == null) return null;
    return resolve(storedPath);
  }

  /// Convert an absolute path to a relative path for storage.
  ///
  /// Strips the documents-directory prefix so the path survives sandbox
  /// UUID changes.
  static String toRelative(String absolutePath) {
    if (_basePath == null) {
      throw StateError('PathResolver.init() must be called before toRelative()');
    }

    // Already relative
    if (!absolutePath.startsWith('/')) return absolutePath;

    // Strip base path prefix
    if (absolutePath.startsWith(_basePath!)) {
      var relative = absolutePath.substring(_basePath!.length);
      if (relative.startsWith('/')) relative = relative.substring(1);
      return relative;
    }

    // Try to extract from moku_books/
    final idx = absolutePath.indexOf('moku_books/');
    if (idx >= 0) return absolutePath.substring(idx);

    return absolutePath;
  }
}
