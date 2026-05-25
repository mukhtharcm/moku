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
import '../../../core/ui/ui.dart';

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

    return BlocListener<SearchCubit, SearchState>(
      listenWhen: (previous, current) => previous.query != current.query,
      listener: (context, state) {
        if (_searchController.text != state.query) {
          _searchController.value = TextEditingValue(
            text: state.query,
            selection: TextSelection.collapsed(offset: state.query.length),
          );
        }
      },
      child: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: state.isAtCatalogList
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => context.read<SearchCubit>().back(),
                      icon: const Icon(Icons.arrow_back),
                    ),
              title: Text(
                _appBarTitle(context, state),
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
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  String _appBarTitle(BuildContext context, SearchState state) {
    final pageTitle = state.currentBrowsePage?.title.trim();
    if (pageTitle != null && pageTitle.isNotEmpty) return pageTitle;
    final catalog = state.selectedCatalog;
    if (catalog != null) return catalogTitleLabel(context, catalog);
    return context.l10n.searchTitle;
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.catalogs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isAtCatalogList) {
      return _CatalogListView(
        catalogs: state.catalogs,
        onOpenCatalog: (catalog) => context.read<SearchCubit>().openCatalog(catalog.id),
      );
    }

    final catalog = state.selectedCatalog;
    if (catalog == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (catalog.supportsSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.l10n.searchHint(
                  catalogTitle: catalogTitleLabel(context, catalog),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.query.isNotEmpty
                    ? IconButton(
                        tooltip: context.l10n.commonClear,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<SearchCubit>().search('');
                        },
                      )
                    : null,
              ),
              onChanged: (query) => context.read<SearchCubit>().search(query),
              onSubmitted: (query) =>
                  context.read<SearchCubit>().submitSearch(query),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: context.colors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.searchErrorCatalogNotSearchable,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: state.isShowingSearchResults
              ? _buildSearchResults(context, state)
              : _buildBrowsePage(context, state),
        ),
      ],
    );
  }

  Widget _buildBrowsePage(BuildContext context, SearchState state) {
    if (state.status == SearchStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == SearchStatus.error) {
      return _SearchStatusMessage(
        icon: Icons.error_outline_rounded,
        message: catalogErrorCodeMessage(context, state.errorCode),
      );
    }

    final page = state.currentBrowsePage;
    if (page == null || page.isEmpty) {
      return _SearchStatusMessage(
        icon: Icons.folder_off_outlined,
        message: context.l10n.searchBrowseEmpty,
      );
    }

    final children = <Widget>[
      for (final entry in page.navigationEntries)
        _CatalogNavigationTile(
          entry: entry,
          onTap: () => context.read<SearchCubit>().openBrowseEntry(entry),
        ),
      for (final book in page.books)
        _buildResultCard(context, state, book),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: children,
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchState state) {
    if (state.status == SearchStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == SearchStatus.error && state.results.isEmpty) {
      return _SearchStatusMessage(
        icon: Icons.error_outline_rounded,
        message: catalogErrorCodeMessage(context, state.errorCode),
      );
    }

    if (state.results.isEmpty) {
      return _SearchStatusMessage(
        icon: Icons.search_off_rounded,
        message: context.l10n.searchEmptyResults,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final book in state.results) _buildResultCard(context, state, book),
      ],
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    SearchState state,
    CatalogBook book,
  ) {
    final isDownloading = state.downloadingBookIds.contains(book.id);
    final isDownloaded = state.downloadedBookIds.contains(book.id);
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
                context.l10n.searchBookAdded(
                  title: bidiWrappedText(context, bookTitle),
                ),
              ),
            ),
          );
        } catch (error) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text(catalogErrorMessage(context, error))),
          );
        }
      },
    );
  }

  Future<void> _showCatalogManager(BuildContext context) async {
    final l10n = context.l10n;
    final searchCubit = context.read<SearchCubit>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return BlocProvider.value(
          value: searchCubit,
          child: SafeArea(
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
          ),
        );
      },
    );
  }

  Future<void> _showAddCatalogDialog(BuildContext context) async {
    final searchCubit = context.read<SearchCubit>();

    await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: searchCubit,
        child: const _AddCatalogDialog(),
      ),
    );
  }
}

class _AddCatalogDialog extends StatefulWidget {
  const _AddCatalogDialog();

  @override
  State<_AddCatalogDialog> createState() => _AddCatalogDialogState();
}

class _AddCatalogDialogState extends State<_AddCatalogDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _urlController = TextEditingController();
    _urlFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await context.read<SearchCubit>().addCustomCatalog(
        title: _titleController.text,
        url: _urlController.text,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = catalogErrorMessage(context, error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.searchAddCustomCatalogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.searchCatalogNameLabel),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _urlFocusNode.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.searchCatalogUrlLabel,
              errorText: _errorText,
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                },
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonAdd),
        ),
      ],
    );
  }
}

class _SearchStatusMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SearchStatusMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
                  color: colors.accent.withValues(alpha: 0.6),
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

class _CatalogListView extends StatelessWidget {
  final List<CatalogSource> catalogs;
  final ValueChanged<CatalogSource> onOpenCatalog;

  const _CatalogListView({
    required this.catalogs,
    required this.onOpenCatalog,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final catalog in catalogs)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () => onOpenCatalog(catalog),
              leading: Icon(
                catalog.isCustom ? Icons.link : Icons.auto_awesome_outlined,
              ),
              title: Text(catalogTitleLabel(context, catalog)),
              subtitle: catalog.isCustom ? Text(catalog.url) : null,
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
      ],
    );
  }
}

class _CatalogNavigationTile extends StatelessWidget {
  final CatalogNavigationEntry entry;
  final VoidCallback onTap;

  const _CatalogNavigationTile({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.folder_outlined),
        title: Text(entry.title),
        subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
        trailing: const Icon(Icons.chevron_right),
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
    final colors = context.colors;
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
                            color: colors.surfaceElevated,
                            child: const Icon(Icons.book, size: 24),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 64,
                            height: 96,
                            color: colors.surfaceElevated,
                            child: const Icon(Icons.book, size: 24),
                          ),
                        )
                      : Container(
                          width: 64,
                          height: 96,
                          color: colors.surfaceElevated,
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
                          color: colors.accent,
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
                  color: colors.textSecondary,
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.accentMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.accent,
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
