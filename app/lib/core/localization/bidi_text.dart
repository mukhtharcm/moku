import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show BidiFormatter;

String bidiWrappedText(BuildContext context, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;

  final formatter = Directionality.of(context) == ui.TextDirection.rtl
      ? BidiFormatter.RTL()
      : BidiFormatter.LTR();
  return formatter.wrapWithUnicode(trimmed);
}
