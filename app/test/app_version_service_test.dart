import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/services/app_version_service.dart';

void main() {
  group('AppVersionService.normalizeVersionInfo', () {
    test('includes the build number when available', () {
      final versionInfo = AppVersionService.normalizeVersionInfo(
        version: '1.1.0',
        buildNumber: '2',
      );

      expect(versionInfo?.version, '1.1.0');
      expect(versionInfo?.buildNumber, '2');
    });

    test('omits the build number when it is blank', () {
      final versionInfo = AppVersionService.normalizeVersionInfo(
        version: '1.1.0',
        buildNumber: ' ',
      );

      expect(versionInfo?.version, '1.1.0');
      expect(versionInfo?.buildNumber, isNull);
    });

    test('falls back when the version string is blank', () {
      expect(
        AppVersionService.normalizeVersionInfo(
          version: ' ',
          buildNumber: '2',
        ),
        isNull,
      );
    });
  });
}
