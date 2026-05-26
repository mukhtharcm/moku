/// Cross-platform helpers used by the design system.
///
/// One source of truth for "are we drawing desktop chrome right now?".
library;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';

class MokuPlatform {
  MokuPlatform._();

  /// True on macOS, Linux, Windows native builds (not web).
  static bool get isNativeDesktop {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }

  /// True on iOS / Android native builds (not web).
  static bool get isNativeMobile {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      default:
        return false;
    }
  }

  /// True when we should draw desktop chrome — native desktop OR a wide
  /// window on any platform (tablet landscape, big browser, etc.).
  ///
  /// Use this in widgets that need to swap densities or button styles.
  static bool useDesktopChrome(BuildContext context) {
    if (isNativeDesktop) return true;
    return MediaQuery.sizeOf(context).width >= 1000;
  }
}
