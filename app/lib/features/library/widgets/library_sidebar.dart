import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/models.dart';
import '../../../core/models/book_localizations.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        final books = state.filteredBooks;

        return Column(
          children: [
            // ── Search ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
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
                    horizontal: 14,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onChanged: (q) =>
                    context.read<LibraryCubit>().setSearchQuery(q),
              ),
            ),

            // ── Header row (count + sort) ───────────────────────────
            if (state.searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Text(
                      l10n.librarySectionTitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${books.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<LibrarySortMode>(
                      tooltip: '',
                      child: Icon(
                        Icons.sort_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (m) =>
                          context.read<LibraryCubit>().setSortMode(m),
                      itemBuilder: (_) =>
                          LibrarySortMode.values.map((m) {
                        return PopupMenuItem(
                          value: m,
                          child: Row(
                            children: [
                              Text(_sortLabel(context, m)),
                              if (m == state.sortMode) ...[
                                const Spacer(),
                                Icon(Icons.check_rounded,
                                    size: 14,
                                    color: colorScheme.primary),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // ── Book list ────────────────────────────────────────────
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
                            return _BookListTile(
                              book: book,
                              progress: progress,
                              isSelected: isSelected,
                              onTap: () => context
                                  .read<LibraryCubit>()
                                  .selectBook(book.id),
                            );
                          },
                        ),
            ),

            // ── Import button ────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      context.read<LibraryCubit>().importBook(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.libraryFabImport),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
      LibrarySortMode.title => l10n.librarySortTitle,
      LibrarySortMode.author => l10n.librarySortAuthor,
    };
  }
}

// ── Individual book tile ─────────────────────────────────────────────────────

class _BookListTile extends StatelessWidget {
  final Book book;
  final double progress;
  final bool isSelected;
  final VoidCallback onTap;

  const _BookListTile({
    required this.book,
    required this.progress,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = bookTitleLabel(context, book.title);
    final author = bookAuthorLabel(context, book.author);

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
            // Cover thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 36,
                height: 52,
                child: BookCoverWidget(
                  book: book,
                  borderRadius: 4,
                  showShadow: false,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.literata(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  if (progress > 0.01) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onImport;

  const _EmptyState({required this.hasSearch, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    if (hasSearch) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(l10n.libraryEmptySearchTitle,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(l10n.libraryEmptyTitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
