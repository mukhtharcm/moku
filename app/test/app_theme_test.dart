import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moku/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('RTL theme adaptation keeps LTR themes untouched', () {
    final baseTheme = MokuTheme.lightTheme();
    final adapted = MokuTheme.adaptForTextDirection(
      baseTheme,
      TextDirection.ltr,
    );

    expect(identical(adapted, baseTheme), isTrue);
  });

  test('RTL theme adaptation swaps away from the Latin-first text theme', () {
    final baseTheme = MokuTheme.lightTheme();
    final adapted = MokuTheme.adaptForTextDirection(
      baseTheme,
      TextDirection.rtl,
    );

    expect(identical(adapted, baseTheme), isFalse);
    expect(
      adapted.textTheme.bodyMedium?.fontFamily,
      isNot(baseTheme.textTheme.bodyMedium?.fontFamily),
    );
  });
}
