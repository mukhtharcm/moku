import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/bidi_text.dart';
import '../../../core/models/book_localizations.dart';
import '../../../core/models/book.dart';
import '../../../core/services/opds_catalog_service.dart';
import '../../../l10n/l10n.dart';
import '../catalog_error_localizations.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.searchTitle,
          style: GoogleFonts.literata(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.searchManageCatalogs,
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
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.searchCatalogLabel,
                    prefixIcon: const Icon(Icons.public),
                  ),
                  selectedItemBuilder: (context) => state.catalogs
                      .map(
                        (catalog) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            catalogTitleLabel(context, catalog),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  items: state.catalogs
                      .map(
                        (catalog) => DropdownMenuItem(
                          value: catalog.id,
                          child: CatalogDropdownItem(catalog: catalog),
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
                final hasQuery = state.query.isNotEmpty;
                final hintCatalog = state.selectedCatalog == null
                    ? l10n.searchGenericCatalogName
                    : catalogTitleLabel(context, state.selectedCatalog!);
                return TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint(catalogTitle: hintCatalog),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: hasQuery
                        ? IconButton(
                            tooltip: l10n.commonClear,
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<SearchCubit>().clear();
                            },
                          )
                        : null,
                  ),
                  onChanged: (query) =>
                      context.read<SearchCubit>().search(query),
                  onSubmitted: (query) =>
                      context.read<SearchCubit>().submitSearch(query),
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

                if (state.query.trim().isEmpty) {
                  return _EmptyPrompt(
                    catalogTitle: state.selectedCatalog == null
                        ? l10n.searchPromptGenericCatalogName
                        : catalogTitleLabel(context, state.selectedCatalog!),
                  );
                }

                if (state.status == SearchStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == SearchStatus.error &&
                    state.results.isEmpty) {
                  final errorText = state.selectedCatalog == null
                      ? l10n.searchNoCatalogSelected
                      : catalogErrorCodeMessage(context, state.errorCode);

                  return _SearchStatusMessage(
                    icon: Icons.error_outline_rounded,
                    message: errorText,
                  );
                }

                if (state.results.isEmpty) {
                  return _SearchStatusMessage(
                    icon: Icons.search_off_rounded,
                    message: l10n.searchEmptyResults,
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
                    final isDownloaded = state.downloadedBookIds.contains(
                      book.id,
                    );
                    return _SearchResultCard(
                      book: book,
                      isDownloading: isDownloading,
                      isDownloaded: isDownloaded,
                      onDownload: () async {
                        final cubit = context.read<SearchCubit>();
                        final messenger = ScaffoldMessenger.of(context);
                        final bookTitle = bookTitleLabel(context, book.title);
                        try {
                          await cubit.downloadBook(book);
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.searchBookAdded(
                                  title: bidiWrappedText(context, bookTitle),
                                ),
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                catalogErrorMessage(context, error),
                              ),
                            ),
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
    final l10n = context.l10n;

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
                    Text(
                      l10n.searchCatalogsTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.searchCatalogsBody,
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
                        title: Text(catalogTitleLabel(context, catalog)),
                        subtitle: Text(catalog.url),
                        trailing: catalog.isCustom
                            ? IconButton(
                                tooltip: l10n.searchRemoveCatalog,
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
                          l10n.searchNoCustomCatalogs,
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
                        label: Text(l10n.searchAddCustomCatalog),
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
    final urlController = TextEditingController();
    final urlFocusNode = FocusNode();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Future<void> submit() async {
          try {
            await context.read<SearchCubit>().addCustomCatalog(
              title: titleController.text,
              url: urlController.text,
            );
            if (!context.mounted || !ctx.mounted) return;
            Navigator.pop(ctx);
          } catch (error) {
            if (!context.mounted || !ctx.mounted) return;
            messenger.showSnackBar(
              SnackBar(content: Text(catalogErrorMessage(context, error))),
            );
          }
        }

        return AlertDialog(
          title: Text(l10n.searchAddCustomCatalogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: l10n.searchCatalogNameLabel,
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => urlFocusNode.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                focusNode: urlFocusNode,
                decoration: InputDecoration(
                  labelText: l10n.searchCatalogUrlLabel,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(onPressed: submit, child: Text(l10n.commonAdd)),
          ],
        );
      },
    );

    titleController.dispose();
    urlController.dispose();
    urlFocusNode.dispose();
  }
}

class CatalogDropdownItem extends StatelessWidget {
  final CatalogSource catalog;

  const CatalogDropdownItem({super.key, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          catalogTitleLabel(context, catalog),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (catalog.isCustom)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.l10n.searchCatalogTypeCustom,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
            ),
          ),
      ],
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  final String catalogTitle;

  const _EmptyPrompt({required this.catalogTitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final title = l10n.searchInitialPromptTitle(catalogTitle: catalogTitle);
    final body = l10n.searchInitialPromptBody;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: MergeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.download_for_offline_outlined,
                    size: 64,
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchStatusMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SearchStatusMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 52,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final CatalogBook book;
  final bool isDownloading;
  final bool isDownloaded;
  final Future<void> Function() onDownload;

  const _SearchResultCard({
    required this.book,
    required this.isDownloading,
    required this.isDownloaded,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final title = bookTitleLabel(context, book.title);
    final author = bookAuthorLabel(context, book.author);
    final catalogTitle = catalogBookTitleLabel(context, book);
    final preferredFormatLabel = _bookFormatLabel(
      context,
      book.preferredAcquisition.format,
    );

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
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        author,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaChip(label: catalogTitle),
                          _MetaChip(
                            label: _catalogFormatSummary(context, book),
                          ),
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
                    onPressed: (isDownloading || isDownloaded)
                        ? null
                        : onDownload,
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isDownloaded
                                ? Icons.check_circle_outline
                                : Icons.download,
                          ),
                    label: Text(
                      isDownloading
                          ? l10n.searchDownloading
                          : isDownloaded
                          ? l10n.searchDownloaded
                          : l10n.searchDownloadFormat(
                              formatName: preferredFormatLabel,
                            ),
                    ),
                  ),
                ),
                if (book.externalUrl != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.searchOpenSourcePage,
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

String _catalogFormatSummary(BuildContext context, CatalogBook book) {
  return book.acquisitions
      .map((item) => _bookFormatLabel(context, item.format))
      .toSet()
      .join(' · ');
}

String _bookFormatLabel(BuildContext context, BookFormat format) {
  final l10n = context.l10n;

  return switch (format) {
    BookFormat.epub => l10n.formatEpub,
    BookFormat.pdf => l10n.formatPdf,
    BookFormat.txt => l10n.formatText,
    BookFormat.cbz => l10n.formatComicCbz,
    BookFormat.html => l10n.formatHtml,
  };
}
