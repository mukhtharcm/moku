import 'dart:async';

import 'package:flutter/services.dart';

class IncomingFileImports {
  IncomingFileImports._();

  static final IncomingFileImports instance = IncomingFileImports._();
  static const MethodChannel _channel = MethodChannel('com.moku/imports');

  final StreamController<List<String>> _pathsController =
      StreamController<List<String>>.broadcast();

  bool _configured = false;

  Stream<List<String>> get paths => _pathsController.stream;

  void configure() {
    if (_configured) return;
    _configured = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'importsAvailable') {
        throw MissingPluginException('Unknown method ${call.method}');
      }

      final paths = await takePendingPaths();
      if (paths.isNotEmpty) {
        _pathsController.add(paths);
      }
    });
  }

  Future<List<String>> takePendingPaths() async {
    try {
      final paths = await _channel.invokeListMethod<String>(
        'takePendingImportPaths',
      );
      return paths ?? const <String>[];
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    }
  }
}
