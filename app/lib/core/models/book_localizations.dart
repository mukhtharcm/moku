import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';

String bookTitleLabel(BuildContext context, String title) {
  final trimmed = title.trim();
  return trimmed.isEmpty ? context.l10n.bookUnknownTitle : trimmed;
}

String bookAuthorLabel(BuildContext context, String author) {
  final trimmed = author.trim();
  return trimmed.isEmpty ? context.l10n.bookUnknownAuthor : trimmed;
}
