import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ui/ui.dart';
import '../../../l10n/l10n.dart';
import '../cubit/collections_cubit.dart';
import '../cubit/collections_state.dart';
import '../screens/collection_detail_screen.dart';

/// The right-hand main pane for the Shelves section on desktop.
class ShelvesDetailPane extends StatelessWidget {
  const ShelvesDetailPane({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectionsCubit, CollectionsState>(
      builder: (context, state) {
        final collection = state.selectedCollection;

        if (collection != null) {
          return CollectionDetailScreen(
            key: ValueKey(collection.id),
            collection: collection,
          );
        }

        return _EmptyPane(
          hasCollections: state.collections.isNotEmpty,
        );
      },
    );
  }
}

class _EmptyPane extends StatelessWidget {
  final bool hasCollections;
  const _EmptyPane({required this.hasCollections});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MokuSpacing.s8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MokuSpacing.contentNarrow),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 56,
                color: colors.accent.withValues(alpha: 0.18),
              ),
              const SizedBox(height: MokuSpacing.s5),
              Text(
                hasCollections
                    ? 'Select a shelf'
                    : l10n.collectionsEmptyTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: MokuSpacing.s2),
              Text(
                hasCollections
                    ? 'Choose a shelf from the sidebar to browse its books.'
                    : 'Organise your library into shelves — '
                      'by genre, reading status, or anything you like.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MokuSpacing.s6),
              // Always provide a way to create a shelf — don't trap the
              // user in the sidebar.
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.collectionsCreateShelf),
              ),
            ],
          ),
        ),
      ),
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
              onSubmitted: (_) {
                if (nameCtrl.text.isNotEmpty) {
                  _create(context, nameCtrl.text, descCtrl.text);
                  Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: MokuSpacing.s3),
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
                _create(context, nameCtrl.text, descCtrl.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    );
  }

  void _create(BuildContext context, String name, String desc) {
    context.read<CollectionsCubit>().createCollection(
      name,
      description: desc.isEmpty ? null : desc,
    );
  }
}
