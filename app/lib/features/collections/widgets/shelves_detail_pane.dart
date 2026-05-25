import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';
import '../cubit/collections_cubit.dart';
import '../cubit/collections_state.dart';
import '../screens/collection_detail_screen.dart';

/// The right-hand main pane for the Shelves section on desktop.
/// Shows the contents of the currently-selected shelf, or an empty
/// placeholder when nothing is selected.
class ShelvesDetailPane extends StatelessWidget {
  const ShelvesDetailPane({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectionsCubit, CollectionsState>(
      builder: (context, state) {
        final collection = state.selectedCollection;

        if (collection != null) {
          // Re-use the existing detail screen — it manages its own stream
          // and already handles add/remove books, empty state, etc.
          return CollectionDetailScreen(
            key: ValueKey(collection.id),
            collection: collection,
          );
        }

        return _EmptyPane();
      },
    );
  }
}

class _EmptyPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 64,
            color: colorScheme.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.collectionsEmptyTitle,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a shelf from the sidebar to see its books.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
