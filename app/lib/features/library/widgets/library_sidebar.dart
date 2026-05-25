import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/book_localizations.dart';
import '../../../core/ui/ui.dart';
import '../../../l10n/l10n.dart';
import '../cubit/library_cubit.dart';
import '../cubit/library_state.dart';
import 'book_cover.dart';

class LibrarySidebar extends StatefulWidget {
  const LibrarySidebar({super.key});

  @override
  State<LibrarySidebar> createState() => _LibrarySidebarState();
}

class _LibrarySidebarState extends State<LibrarySidebar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        final books = state.filteredBooks;

        return Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(MokuSpacing.s2),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.librarySearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            context.read<LibraryCubit>().setSearchQuery('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                onChanged: (q) =>
                    context.read<LibraryCubit>().setSearchQuery(q),
              ),
            ),

            // Section header
            MokuPanelHeader(
              label: '${l10n.librarySectionTitle}  ${books.length}',
              trailing: PopupMenuButton<LibrarySortMode>(
                tooltip: '',
                child: Icon(Icons.sort_rounded,
                    size: 16, color: colors.textSecondary),
                onSelected: (m) =>
                    context.read<LibraryCubit>().setSortMode(m),
                itemBuilder: (_) => LibrarySortMode.values.map((m) {
                  return PopupMenuItem(
                    value: m,
                    child: Row(children: [
                      Text(_sortLabel(context, m)),
                      if (m == state.sortMode) ...[
                        const Spacer(),
                        Icon(Icons.check_rounded,
                            size: 14, color: colors.accent),
                      ],
                    ]),
                  );
                }).toList(),
              ),
            ),

            // Book list
            Expanded(
              child: state.status == LibraryStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : books.isEmpty
                      ? _EmptyState(
                          hasSearch: state.searchQuery.isNotEmpty,
                          onImport: () =>
                              context.read<LibraryCubit>().importBook(),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: books.length,
                          itemBuilder: (context, index) {
                            final book = books[index];
                            final progress =
                                state.progressMap[book.id] ?? 0.0;
                            final isSelected =
                                state.selectedBookId == book.id;
                            return MokuPanelItem(
                              leading: ClipRRect(
                                borderRadius: MokuRadius.xsAll,
                                child: SizedBox(
                                  width: 34,
                                  height: 50,
                                  child: BookCoverWidget(
                                    book: book,
                                    borderRadius: MokuRadius.xs,
                                    showShadow: false,
                                  ),
                                ),
                              ),
                              title: bookTitleLabel(context, book.title),
                              subtitle: bookAuthorLabel(context, book.author),
                              selected: isSelected,
                              onTap: () => context
                                  .read<LibraryCubit>()
                                  .selectBook(book.id),
                              trailing: progress > 0.01
                                  ? SizedBox(
                                      width: 32,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          MokuProgressBar(progress: progress),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${(progress * 100).round()}%',
                                            style: MokuText.micro(
                                              color: colors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
            ),

            // Import button
            const MokuPanelDivider(),
            Padding(
              padding: const EdgeInsets.all(MokuSpacing.s3),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      context.read<LibraryCubit>().importBook(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.libraryFabImport),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: MokuSpacing.s2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _sortLabel(BuildContext context, LibrarySortMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      LibrarySortMode.recent => l10n.librarySortRecent,
      LibrarySortMode.title  => l10n.librarySortTitle,
      LibrarySortMode.author => l10n.librarySortAuthor,
    };
  }
}

// Empty state

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onImport;
  const _EmptyState({required this.hasSearch, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    if (hasSearch) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 36,
                color: colors.textTertiary),
            const SizedBox(height: MokuSpacing.s3),
            Text(l10n.libraryEmptySearchTitle,
                style: MokuText.bodySmall(
                    color: colors.textSecondary)),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MokuSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 36,
                color: colors.textTertiary),
            const SizedBox(height: MokuSpacing.s3),
            Text(l10n.libraryEmptyTitle,
                style: MokuText.bodySmall(
                    color: colors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
