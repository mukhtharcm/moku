import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/models.dart';
import '../cubit/library_cubit.dart';
import '../cubit/library_state.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_grid_item.dart';
import '../../reader/screens/reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search books...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (query) {
                  context.read<LibraryCubit>().setSearchQuery(query);
                },
              )
            : const Text('Moku'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  context.read<LibraryCubit>().setSearchQuery('');
                }
              });
            },
          ),
          BlocBuilder<LibraryCubit, LibraryState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.viewMode == LibraryView.grid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                ),
                onPressed: () {
                  context.read<LibraryCubit>().toggleViewMode();
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          if (state.status == LibraryStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == LibraryStatus.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'An error occurred',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      context.read<LibraryCubit>().loadBooks();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final books = state.filteredBooks;

          if (state.books.isEmpty) {
            return _EmptyLibrary(
              hasSearch: false,
              onImport: () {
                context.read<LibraryCubit>().importBook();
              },
            );
          }

          if (books.isEmpty && state.searchQuery.isNotEmpty) {
            return _EmptyLibrary(
              hasSearch: true,
              onImport: () {},
            );
          }

          // Show "Continue Reading" section + full library
          final currentlyReading = state.currentlyReading;

          return CustomScrollView(
            slivers: [
              // Continue Reading section
              if (currentlyReading.isNotEmpty && state.searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: _ContinueReadingSection(
                    books: currentlyReading.take(5).toList(),
                    progressMap: state.progressMap,
                    onBookTap: (book) => _openReader(context, book),
                  ),
                ),

              // Sort chip
              if (state.searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          '${books.length} book${books.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const Spacer(),
                        PopupMenuButton<LibrarySortMode>(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort, size: 16,
                                  color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(state.sortMode),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          onSelected: (mode) =>
                              context.read<LibraryCubit>().setSortMode(mode),
                          itemBuilder: (_) => LibrarySortMode.values.map((m) {
                            return PopupMenuItem(
                              value: m,
                              child: Row(
                                children: [
                                  Text(_sortLabel(m)),
                                  if (m == state.sortMode) ...[
                                    const Spacer(),
                                    const Icon(Icons.check, size: 16),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

              // Main library grid/list
              if (state.viewMode == LibraryView.grid)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = books[index];
                        return BookGridItem(
                          book: book,
                          progress: state.progressMap[book.id],
                          onTap: () => _openReader(context, book),
                          onLongPress: () =>
                              _showBookOptions(context, book),
                        );
                      },
                      childCount: books.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = books[index];
                        final progress = state.progressMap[book.id];
                        return ListTile(
                          leading: SizedBox(
                            width: 40,
                            height: 60,
                            child: BookCoverWidget(
                                book: book, borderRadius: 6),
                          ),
                          title: Text(book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: progress != null && progress > 0.01
                              ? SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 3,
                                    backgroundColor: colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                )
                              : null,
                          onTap: () => _openReader(context, book),
                          onLongPress: () =>
                              _showBookOptions(context, book),
                        );
                      },
                      childCount: books.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<LibraryCubit>().importBook();
        },
        icon: const Icon(Icons.add),
        label: const Text('Import'),
      ),
    );
  }

  String _sortLabel(LibrarySortMode mode) {
    switch (mode) {
      case LibrarySortMode.recent:
        return 'Recent';
      case LibrarySortMode.title:
        return 'Title';
      case LibrarySortMode.author:
        return 'Author';
    }
  }

  void _openReader(BuildContext context, Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book),
      ),
    );
  }

  void _showBookOptions(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Book Info'),
              onTap: () {
                Navigator.pop(ctx);
                _showBookInfo(context, book);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, book);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBookInfo(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(book.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(book.author,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      )),
              if (book.description != null) ...[
                const SizedBox(height: 16),
                Text(book.description!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              _InfoRow('Chapters', '${book.totalChapters}'),
              if (book.publisher != null)
                _InfoRow('Publisher', book.publisher!),
              if (book.language != null)
                _InfoRow('Language', book.language!),
              if (book.isbn != null)
                _InfoRow('ISBN', book.isbn!),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Remove "${book.title}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<LibraryCubit>().deleteBook(book.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onImport;

  const _EmptyLibrary({required this.hasSearch, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (hasSearch) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No books match your search',
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 80, color: colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              'Your library is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import EPUB books to start reading',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open),
              label: const Text('Import EPUB'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingSection extends StatelessWidget {
  final List<Book> books;
  final Map<String, double> progressMap;
  final void Function(Book) onBookTap;

  const _ContinueReadingSection({
    required this.books,
    required this.progressMap,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Continue Reading',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final progress = progressMap[book.id] ?? 0.0;

              return GestureDetector(
                onTap: () => onBookTap(book),
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            height: 110,
                            child: BookCoverWidget(
                                book: book, borderRadius: 8),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  book.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.author,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme
                                            .onSurfaceVariant,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
