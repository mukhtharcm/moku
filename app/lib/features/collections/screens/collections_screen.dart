import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/models.dart';
import '../../../l10n/l10n.dart';
import '../cubit/collections_cubit.dart';
import '../cubit/collections_state.dart';
import 'collection_detail_screen.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.collectionsTitle,
          style: GoogleFonts.literata(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: BlocBuilder<CollectionsCubit, CollectionsState>(
        builder: (context, state) {
          if (state.status == CollectionsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.collections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.collections_bookmark_outlined,
                        size: 44,
                        color: colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.collectionsEmptyTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.collectionsEmptyBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _showCreateDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.collectionsCreateShelf),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: state.collections.length,
            itemBuilder: (context, index) {
              final collection = state.collections[index];
              return _CollectionCard(
                collection: collection,
                onTap: () => _openCollection(context, collection),
                onDelete: () => _confirmDelete(context, collection),
              );
            },
          );
        },
      ),
      floatingActionButton: BlocBuilder<CollectionsCubit, CollectionsState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.collections != current.collections,
        builder: (context, state) {
          if (state.status == CollectionsStatus.loading ||
              state.collections.isEmpty) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton(
            heroTag: 'collections_create',
            onPressed: () => _showCreateDialog(context),
            tooltip: l10n.collectionsCreateShelf,
            child: const Icon(Icons.add_rounded),
          );
        },
      ),
    );
  }

  void _openCollection(BuildContext context, BookCollection collection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(collection: collection),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.collectionsNewShelfTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.collectionsNameLabel,
                hintText: l10n.collectionsNameHint,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
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
              if (nameController.text.isNotEmpty) {
                context.read<CollectionsCubit>().createCollection(
                  nameController.text,
                  description: descController.text.isEmpty
                      ? null
                      : descController.text,
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
          l10n.collectionsDeleteShelfMessage(name: collection.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              context.read<CollectionsCubit>().deleteCollection(collection.id);
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

class _CollectionCard extends StatelessWidget {
  final BookCollection collection;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    // Generate a colour from collection name hash
    final hash = collection.name.hashCode;
    final hue = (hash % 360).toDouble().abs();
    final iconColor = HSLColor.fromAHSL(1, hue, 0.5, 0.6).toColor();
    final bgColor = HSLColor.fromAHSL(0.12, hue, 0.5, 0.6).toColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          minLeadingWidth: 48,
          horizontalTitleGap: 14,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.collections_bookmark_rounded,
              color: iconColor,
              size: 22,
            ),
          ),
          title: Text(
            collection.name,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: collection.description == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    collection.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
          trailing: IconButton(
            tooltip: l10n.collectionsDeleteShelfTitle,
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
          ),
        ),
      ),
    );
  }
}
