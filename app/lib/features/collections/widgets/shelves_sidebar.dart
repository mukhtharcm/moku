import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/models.dart';
import '../../../l10n/l10n.dart';
import '../cubit/collections_cubit.dart';
import '../cubit/collections_state.dart';

class ShelvesSidebar extends StatelessWidget {
  const ShelvesSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return BlocBuilder<CollectionsCubit, CollectionsState>(
      builder: (context, state) {
        return Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    l10n.collectionsTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    tooltip: l10n.collectionsCreateShelf,
                    onPressed: () => _showCreateDialog(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Shelf list ────────────────────────────────────────
            Expanded(
              child: state.status == CollectionsStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.collections.isEmpty
                      ? _EmptyState(
                          onCreate: () => _showCreateDialog(context))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: state.collections.length,
                          itemBuilder: (context, index) {
                            final collection = state.collections[index];
                            final isSelected =
                                state.selectedCollectionId == collection.id;
                            return _ShelfTile(
                              collection: collection,
                              isSelected: isSelected,
                              onTap: () => context
                                  .read<CollectionsCubit>()
                                  .selectCollection(collection.id),
                              onDelete: () =>
                                  _confirmDelete(context, collection),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.collectionsNewShelfTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.collectionsNameLabel,
                hintText: l10n.collectionsNameHint,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: l10n.collectionsDescriptionOptionalLabel,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<CollectionsCubit>().createCollection(
                  nameCtrl.text,
                  description:
                      descCtrl.text.isEmpty ? null : descCtrl.text,
                );
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, BookCollection collection) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.collectionsDeleteShelfTitle),
        content: Text(
            l10n.collectionsDeleteShelfMessage(name: collection.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              context
                  .read<CollectionsCubit>()
                  .deleteCollection(collection.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

class _ShelfTile extends StatelessWidget {
  final BookCollection collection;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ShelfTile({
    required this.collection,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hash = collection.name.hashCode;
    final hue = (hash % 360).toDouble().abs();
    final iconColor = HSLColor.fromAHSL(1, hue, 0.5, 0.6).toColor();
    final bgColor = HSLColor.fromAHSL(0.15, hue, 0.5, 0.6).toColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.collections_bookmark_rounded,
                  size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (collection.description != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      collection.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 16, color: colorScheme.error.withValues(alpha: 0.6)),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.collectionsDeleteShelfTitle,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(l10n.collectionsEmptyTitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(l10n.collectionsCreateShelf),
            ),
          ],
        ),
      ),
    );
  }
}
