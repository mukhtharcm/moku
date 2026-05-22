import 'package:package_info_plus/package_info_plus.dart';

class AppVersionInfo {
  final String version;
  final String? buildNumber;

  const AppVersionInfo({required this.version, this.buildNumber});
}

class AppVersionService {
  static Future<AppVersionInfo?>? _cachedVersionInfo;

  static Future<AppVersionInfo?> get versionInfo =>
      _cachedVersionInfo ??= _loadVersionInfo();

  static Future<AppVersionInfo?> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return normalizeVersionInfo(
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
    } catch (_) {
      return null;
    }
  }

  static AppVersionInfo? normalizeVersionInfo({
    required String version,
    required String buildNumber,
  }) {
    final normalizedVersion = version.trim();
    final normalizedBuild = buildNumber.trim();

    if (normalizedVersion.isEmpty) {
      return null;
    }

    return AppVersionInfo(
      version: normalizedVersion,
      buildNumber: normalizedBuild.isEmpty ? null : normalizedBuild,
    );
  }
}
