// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart';
import 'package:moku/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fontAssets = [
    'google_fonts/InstrumentSerif-Regular.ttf',
    'google_fonts/DMSans-Regular.ttf',
    'google_fonts/DMSans-Medium.ttf',
    'google_fonts/DMSans-SemiBold.ttf',
  ];
  late Uint8List fontBytes;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    fontBytes = await _loadTestFontBytes();
    assetManifest = _TestAssetManifest(fontAssets);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final assetKey = utf8.decode(message!.buffer.asUint8List());
          if (fontAssets.contains(assetKey)) {
            return ByteData.sublistView(Uint8List.fromList(fontBytes));
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

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

Future<Uint8List> _loadTestFontBytes() async {
  const candidatePaths = [
    '/System/Library/Fonts/SFNS.ttf',
    '/System/Library/Fonts/SFNSMono.ttf',
    '/Library/Fonts/Arial Unicode.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
  ];

  for (final path in candidatePaths) {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsBytes();
    }
  }

  throw StateError('No usable test font found on this machine.');
}

class _TestAssetManifest implements AssetManifest {
  _TestAssetManifest(this.assets);

  final List<String> assets;

  @override
  List<String> listAssets() => assets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}
