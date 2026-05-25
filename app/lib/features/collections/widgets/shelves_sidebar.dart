import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/models.dart';
import '../../../core/ui/ui.dart';
import '../../../l10n/l10n.dart';
import '../cubit/collections_cubit.dart';
import '../cubit/collections_state.dart';

class ShelvesSidebar extends StatelessWidget {
  const ShelvesSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<CollectionsCubit, CollectionsState>(
      builder: (context, state) {
        return Column(
          children: [
            MokuPanelHeader(
              label: l10n.collectionsTitle,
              trailing: IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                tooltip: l10n.collectionsCreateShelf,
                onPressed: () => _showCreateDialog(context),
                visualDensity: VisualDensity.compact,
              ),
            ),

            Expanded(
              child: state.status == CollectionsStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.collections.isEmpty
                      ? _EmptyState(
                          onCreate: () => _showCreateDialog(context))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              vertical: MokuSpacing.s1),
                          itemCount: state.collections.length,
                          itemBuilder: (context, index) {
                            final col = state.collections[index];
                            final isSelected =
                                state.selectedCollectionId == col.id;

                            final hash = col.name.hashCode;
                            final hue = (hash % 360).toDouble().abs();
                            final iconColor =
                                HSLColor.fromAHSL(1, hue, 0.5, 0.55)
                                    .toColor();
                            final bgColor =
                                HSLColor.fromAHSL(0.15, hue, 0.5, 0.6)
                                    .toColor();

                            return MokuPanelItem(
                              leading: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: MokuRadius.smAll,
                                ),
                                child: Icon(
                                    Icons.collections_bookmark_rounded,
                                    size: 14,
                                    color: iconColor),
                              ),
                              title: col.name,
                              subtitle: col.description,
                              selected: isSelected,
                              onTap: () => context
                                  .read<CollectionsCubit>()
                                  .selectCollection(col.id),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error
                                      .withValues(alpha: 0.55),
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, col),
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.collectionsDeleteShelfTitle,
                              ),
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
                  hintText: l10n.collectionsNameHint),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: MokuSpacing.s3),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                  labelText: l10n.collectionsDescriptionOptionalLabel),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
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

  void _confirmDelete(BuildContext context, BookCollection col) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.collectionsDeleteShelfTitle),
        content: Text(
            l10n.collectionsDeleteShelfMessage(name: col.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              context.read<CollectionsCubit>().deleteCollection(col.id);
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MokuSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 36,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35)),
            const SizedBox(height: MokuSpacing.s3),
            Text(l10n.collectionsEmptyTitle,
                style: MokuText.bodySmall(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: MokuSpacing.s3),
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
