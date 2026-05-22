import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';

String syncCollectionLabel(BuildContext context, String collectionId) {
  final l10n = context.l10n;

  return switch (collectionId) {
    'books' => l10n.syncCollectionBooks,
    'reading_progress' => l10n.syncCollectionReadingProgress,
    'bookmarks' => l10n.syncCollectionBookmarks,
    'highlights' => l10n.syncCollectionHighlights,
    'collections' => l10n.syncCollectionShelves,
    'collection_books' => l10n.syncCollectionShelfBooks,
    'reading_sessions' => l10n.syncCollectionReadingSessions,
    'reading_goals' => l10n.syncCollectionReadingGoals,
    _ => l10n.syncCollectionUnknown,
  };
}

String syncCollectionsSummary(BuildContext context, List<String> collectionIds) {
  return collectionIds
      .map((collectionId) => syncCollectionLabel(context, collectionId))
      .toSet()
      .join(', ');
}
