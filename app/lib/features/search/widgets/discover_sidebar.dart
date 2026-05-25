import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/opds_catalog_service.dart';
import '../../../l10n/l10n.dart';
import '../catalog_error_localizations.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';

/// Left sidebar for the Discover section: shows the catalog list.
/// Selecting a catalog drives the main pane via [SearchCubit].
class DiscoverSidebar extends StatelessWidget {
  const DiscoverSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        return Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    l10n.searchTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.library_add_outlined, size: 18),
                    tooltip: l10n.searchManageCatalogs,
                    onPressed: () => _showManageCatalogs(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Catalog list ──────────────────────────────────────
            Expanded(
              child: state.catalogs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: state.catalogs.length,
                      itemBuilder: (context, index) {
                        final catalog = state.catalogs[index];
                        final isSelected =
                            state.selectedCatalogId == catalog.id;
                        return _CatalogTile(
                          catalog: catalog,
                          isSelected: isSelected,
                          onTap: () =>
                              context.read<SearchCubit>().openCatalog(catalog.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showManageCatalogs(BuildContext context) {
    final l10n = context.l10n;
    final searchCubit = context.read<SearchCubit>();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: searchCubit,
        child: BlocBuilder<SearchCubit, SearchState>(
          builder: (context, state) {
            return AlertDialog(
              title: Text(l10n.searchCatalogsTitle),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.searchCatalogsBody,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    ...state.catalogs.map(
                      (catalog) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(catalog.isCustom
                            ? Icons.link
                            : Icons.auto_awesome_outlined),
                        title: Text(catalogTitleLabel(context, catalog)),
                        subtitle:
                            catalog.isCustom ? Text(catalog.url) : null,
                        trailing: catalog.isCustom
                            ? IconButton(
                                tooltip: l10n.searchRemoveCatalog,
                                icon:
                                    const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await context
                                      .read<SearchCubit>()
                                      .removeCustomCatalog(catalog.id);
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _showAddCatalog(context);
                        },
                        icon: const Icon(Icons.add),
                        label: Text(l10n.searchAddCustomCatalog),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonCancel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddCatalog(BuildContext context) async {
    final searchCubit = context.read<SearchCubit>();
    final l10n = context.l10n;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: searchCubit,
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(l10n.searchAddCustomCatalogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                        labelText: l10n.searchCatalogNameLabel),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.searchCatalogUrlLabel,
                      errorText: errorText,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await context.read<SearchCubit>().addCustomCatalog(
                        title: titleCtrl.text,
                        url: urlCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    } catch (e) {
                      setState(() => errorText = e.toString());
                    }
                  },
                  child: Text(l10n.commonAdd),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final CatalogSource catalog;
  final bool isSelected;
  final VoidCallback onTap;

  const _CatalogTile({
    required this.catalog,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              catalog.isCustom
                  ? Icons.link_rounded
                  : Icons.auto_awesome_outlined,
              size: 18,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                catalogTitleLabel(context, catalog),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
