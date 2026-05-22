import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  static Future<String>? _cachedDisplayVersion;

  static Future<String> get displayVersion =>
      _cachedDisplayVersion ??= _loadDisplayVersion();

  static Future<String> _loadDisplayVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return formatDisplayVersion(
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
    } catch (_) {
      return 'Version unavailable';
    }
  }

  static String formatDisplayVersion({
    required String version,
    required String buildNumber,
  }) {
    final normalizedVersion = version.trim();
    final normalizedBuild = buildNumber.trim();

    if (normalizedVersion.isEmpty) {
      return 'Version unavailable';
    }

    if (normalizedBuild.isEmpty) {
      return 'Version $normalizedVersion';
    }

    return 'Version $normalizedVersion ($normalizedBuild)';
  }
}
