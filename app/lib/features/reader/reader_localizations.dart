import 'package:flutter/widgets.dart';

import '../../core/localization/bidi_text.dart';
import '../../l10n/l10n.dart';
import 'cubit/reader_state.dart';

String readerChapterTitle(
  BuildContext context,
  ReaderState state,
  int chapterIndex,
) {
  if (chapterIndex >= 0 && chapterIndex < state.chapters.length) {
    final title = state.chapters[chapterIndex].title.trim();
    if (title.isNotEmpty) {
      return title;
    }
  }

  return context.l10n.readerChapterLabel(chapterNumber: chapterIndex + 1);
}

String readerFontFamilyLabel(BuildContext context, ReaderFontFamily family) {
  final l10n = context.l10n;

  return switch (family) {
    ReaderFontFamily.system => l10n.readerFontFamilySystem,
    ReaderFontFamily.serif => l10n.readerFontFamilySerif,
    ReaderFontFamily.sansSerif => l10n.readerFontFamilySansSerif,
    ReaderFontFamily.mono => l10n.readerFontFamilyMonospace,
  };
}

String readerContentDirectionLabel(BuildContext context, ReaderState state) {
  return state.isContentRtl
      ? context.l10n.readerDirectionRightToLeft
      : context.l10n.readerDirectionLeftToRight;
}

String readerQuotedSelection(BuildContext context, String text) {
  return context.l10n.readerQuotedSelection(
    text: bidiWrappedText(context, text),
  );
}
