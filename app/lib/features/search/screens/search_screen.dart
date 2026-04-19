import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/open_library_service.dart';
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
        title: const Text('Discover'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Open Library...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: BlocBuilder<SearchCubit, SearchState>(
                  builder: (context, state) {
                    if (state.query.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        context.read<SearchCubit>().clear();
                      },
                    );
                  },
                ),
              ),
              onChanged: (q) => context.read<SearchCubit>().search(q),
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                if (state.status == SearchStatus.initial) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_outlined,
                            size: 64,
                            color: colorScheme.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Search for books',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Powered by Open Library',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                if (state.status == SearchStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == SearchStatus.error) {
                  return Center(
                    child: Text('Error: ${state.errorMessage}'),
                  );
                }

                if (state.results.isEmpty) {
                  return const Center(child: Text('No results found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final book = state.results[index];
                    return _SearchResultCard(book: book);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final OpenLibraryBook book;

  const _SearchResultCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showBookDetail(context, book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: book.coverUrl!,
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 90,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.book, size: 24),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 90,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.book, size: 24),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 90,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.book, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.authorString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.firstPublishYear != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${book.firstPublishYear}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (book.subjects.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: book.subjects.take(3).map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showBookDetail(BuildContext context, OpenLibraryBook book) {
    final colorScheme = Theme.of(context).colorScheme;
    final largeCover = book.coverId != null
        ? OpenLibraryService.getCoverUrl(book.coverId, size: 'L')
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
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
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Cover + basic info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: largeCover != null
                        ? CachedNetworkImage(
                            imageUrl: largeCover,
                            width: 120,
                            height: 180,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 120,
                              height: 180,
                              color: colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.book, size: 40),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 120,
                              height: 180,
                              color: colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.book, size: 40),
                            ),
                          )
                        : Container(
                            width: 120,
                            height: 180,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.book, size: 40),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          book.authorString,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                        ),
                        if (book.firstPublishYear != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'First published ${book.firstPublishYear}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        if (book.pageCount != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${book.pageCount} pages',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Publishers
              if (book.publishers.isNotEmpty) ...[
                Text('Publishers',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  book.publishers.take(3).join(', '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              // Subjects
              if (book.subjects.isNotEmpty) ...[
                Text('Subjects',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: book.subjects.map((s) {
                    return Chip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: colorScheme.secondaryContainer,
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              // ISBN
              if (book.isbn.isNotEmpty) ...[
                Text('ISBN', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  book.isbn.first,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 16),
              ],
              // Actions
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final url = Uri.parse(
                        'https://openlibrary.org${book.key}');
                    launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View on Open Library'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
