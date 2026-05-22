import 'package:flutter_test/flutter_test.dart';
import 'package:moku/core/services/app_version_service.dart';

void main() {
  group('AppVersionService.formatDisplayVersion', () {
    test('includes the build number when available', () {
      expect(
        AppVersionService.formatDisplayVersion(
          version: '1.1.0',
          buildNumber: '2',
        ),
        'Version 1.1.0 (2)',
      );
    });

    test('omits the build number when it is blank', () {
      expect(
        AppVersionService.formatDisplayVersion(
          version: '1.1.0',
          buildNumber: ' ',
        ),
        'Version 1.1.0',
      );
    });

    test('falls back when the version string is blank', () {
      expect(
        AppVersionService.formatDisplayVersion(version: ' ', buildNumber: '2'),
        'Version unavailable',
      );
    });
  });
}
