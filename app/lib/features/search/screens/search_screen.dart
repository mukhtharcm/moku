import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/opds_catalog_service.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discover',
          style: GoogleFonts.literata(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Manage catalogs',
            onPressed: () => _showCatalogManager(context),
            icon: const Icon(Icons.library_add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: BlocBuilder<SearchCubit, SearchState>(
              buildWhen: (previous, current) =>
                  previous.catalogs != current.catalogs ||
                  previous.selectedCatalogId != current.selectedCatalogId,
              builder: (context, state) {
                final selected = state.selectedCatalog;
                return DropdownButtonFormField<String>(
                  initialValue: selected?.id,
                  decoration: const InputDecoration(
                    labelText: 'Catalog',
                    prefixIcon: Icon(Icons.public),
                  ),
                  items: state.catalogs
                      .map(
                        (catalog) => DropdownMenuItem(
                          value: catalog.id,
                          child: Row(
                            children: [
                              Expanded(child: Text(catalog.title)),
                              if (catalog.isCustom)
                                Text(
                                  'Custom',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: colorScheme.primary),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SearchCubit>().selectCatalog(value);
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BlocBuilder<SearchCubit, SearchState>(
              buildWhen: (previous, current) =>
                  previous.selectedCatalogId != current.selectedCatalogId ||
                  previous.query != current.query,
              builder: (context, state) {
                final hintCatalog = state.selectedCatalog?.title ?? 'catalog';
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search $hintCatalog...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<SearchCubit>().clear();
                            },
                          ),
                  ),
                  onChanged: (query) =>
                      context.read<SearchCubit>().search(query),
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                if (state.catalogs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == SearchStatus.initial) {
                  return _EmptyPrompt(
                    catalogTitle: state.selectedCatalog?.title ?? 'a catalog',
                  );
                }

                if (state.status == SearchStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == SearchStatus.error &&
                    state.results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        state.errorMessage ?? 'Something went wrong.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                if (state.results.isEmpty) {
                  return const Center(
                    child: Text('No downloadable books found'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final book = state.results[index];
                    final isDownloading = state.downloadingBookIds.contains(
                      book.id,
                    );
                    return _SearchResultCard(
                      book: book,
                      isDownloading: isDownloading,
                      onDownload: () async {
                        final cubit = context.read<SearchCubit>();
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await cubit.downloadBook(book);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${book.title} added to your library',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Download failed: $error')),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCatalogManager(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                final customCatalogs = state.catalogs
                    .where((item) => item.isCustom)
                    .toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catalogs', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Built-ins are ready to use. Add your own OPDS catalogs too.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ...state.catalogs.map(
                      (catalog) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          catalog.isCustom
                              ? Icons.link
                              : Icons.auto_awesome_outlined,
                        ),
                        title: Text(catalog.title),
                        subtitle: Text(catalog.url),
                        trailing: catalog.isCustom
                            ? IconButton(
                                tooltip: 'Remove catalog',
                                onPressed: () async {
                                  await context
                                      .read<SearchCubit>()
                                      .removeCustomCatalog(catalog.id);
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  _showCatalogManager(context);
                                },
                                icon: const Icon(Icons.delete_outline),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    if (customCatalogs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No custom catalogs yet.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _showAddCatalogDialog(context);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Custom Catalog'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddCatalogDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController(text: 'https://');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Catalog'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Catalog name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'Catalog URL'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<SearchCubit>().addCustomCatalog(
                  title: titleController.text,
                  url: urlController.text,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (error) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not add catalog: $error')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  final String catalogTitle;

  const _EmptyPrompt({required this.catalogTitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search $catalogTitle',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Find downloadable books and add them straight to your library.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final CatalogBook book;
  final bool isDownloading;
  final Future<void> Function() onDownload;

  const _SearchResultCard({
    required this.book,
    required this.isDownloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: book.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: book.coverUrl!,
                          width: 64,
                          height: 96,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 64,
                            height: 96,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.book, size: 24),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 64,
                            height: 96,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.book, size: 24),
                          ),
                        )
                      : Container(
                          width: 64,
                          height: 96,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.book, size: 24),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaChip(label: book.catalogTitle),
                          _MetaChip(label: book.formatSummary),
                          if (book.yearLabel != null)
                            _MetaChip(label: book.yearLabel!),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (book.description != null && book.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                book.description!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (book.subjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: book.subjects
                    .map((subject) => _MetaChip(label: subject))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isDownloading ? null : onDownload,
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      isDownloading
                          ? 'Downloading...'
                          : 'Download ${book.preferredAcquisition.format.displayName}',
                    ),
                  ),
                ),
                if (book.externalUrl != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Open source page',
                    onPressed: () {
                      launchUrl(
                        Uri.parse(book.externalUrl!),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
