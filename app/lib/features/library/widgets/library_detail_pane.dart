import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/models.dart';
import '../../../core/models/book_localizations.dart';
import '../../../core/ui/ui.dart';
import '../../../l10n/l10n.dart';
import '../cubit/library_cubit.dart';
import '../cubit/library_state.dart';
import 'book_cover.dart';
import '../../reader/screens/reader_screen.dart';

class LibraryDetailPane extends StatelessWidget {
  /// When provided (desktop inline mode) opening a book calls this callback
  /// instead of pushing a route. The shell replaces the main pane.
  final void Function(Book)? onOpenBook;

  const LibraryDetailPane({super.key, this.onOpenBook});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        final book = state.selectedBook;
        if (book != null) {
          return _BookDetailView(
            book: book,
            progress: state.progressMap[book.id] ?? 0.0,
            onOpenReader: () => _openReader(context, book),
            onDelete: () => _confirmDelete(context, book),
          );
        }
        return _WelcomePane(state: state, onOpenBook: onOpenBook);
      },
    );
  }

  void _openReader(BuildContext context, Book book) {
    if (onOpenBook != null) {
      onOpenBook!(book);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
      );
    }
  }

  void _confirmDelete(BuildContext context, Book book) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.libraryDeleteBookTitle),
        content: Text(l10n.libraryDeleteBookMessage(
          title: bookTitleLabel(context, book.title),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              context.read<LibraryCubit>().deleteBook(book.id);
              context.read<LibraryCubit>().selectBook(null);
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

// ── Book detail view ─────────────────────────────────────────────────────────

class _BookDetailView extends StatelessWidget {
  final Book book;
  final double progress;
  final VoidCallback onOpenReader;
  final VoidCallback onDelete;

  const _BookDetailView({
    required this.book,
    required this.progress,
    required this.onOpenReader,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final title = bookTitleLabel(context, book.title);
    final author = bookAuthorLabel(context, book.author);
    final hasProgress = progress > 0.01;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 28, 40, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // ── Cover + metadata ─────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover
                    Hero(
                      tag: 'book-cover-${book.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 140,
                          height: 200,
                          child: BookCoverWidget(
                            book: book,
                            borderRadius: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: MokuText.bookTitle(color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            author,
                            style: MokuText.body(color: colorScheme.primary, weight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                          // Progress
                          if (hasProgress) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.libraryProgressRead(
                                progress: (progress * 100).toInt(),
                              ),
                              style:
                                  MokuText.caption(color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Format badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                              borderRadius:
                                  BorderRadius.circular(MokuRadius.xs),
                            ),
                            child: Text(
                              book.format.name.toUpperCase(),
                              style: MokuText.micro(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Actions ──────────────────────────────────────────
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onOpenReader,
                      icon: Icon(
                        hasProgress
                            ? Icons.play_arrow_rounded
                            : Icons.menu_book_rounded,
                        size: 16,
                      ),
                      label: Text(
                        hasProgress
                            ? l10n.libraryContinueReading
                            : 'Open Book',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 16, color: colorScheme.error),
                      label: Text(
                        context.l10n.commonDelete,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),

                // ── Description ──────────────────────────────────────
                if (book.description != null &&
                    book.description!.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'About',
                    style: MokuText.sectionLabel(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stripHtml(book.description!),
                    style: MokuText.body(color: colorScheme.onSurface.withValues(alpha: 0.85)),
                  ),
                ],

                // ── Metadata ─────────────────────────────────────────
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 16),
                _MetaGrid(book: book),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      );
  }
}

class _MetaGrid extends StatelessWidget {
  final Book book;
  const _MetaGrid({required this.book});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = <(String, String)>[
      (l10n.libraryInfoChapters, '${book.totalChapters}'),
      if (book.language != null) (l10n.libraryInfoLanguage, book.language!),
      if (book.publisher != null) (l10n.libraryInfoPublisher, book.publisher!),
      if (book.isbn != null) (l10n.libraryInfoIsbn, book.isbn!),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: items
          .map((item) => _MetaItem(label: item.$1, value: item.$2))
          .toList(),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MokuText.caption(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: MokuText.body(weight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Welcome / empty pane ─────────────────────────────────────────────────────

class _WelcomePane extends StatelessWidget {
  final LibraryState state;
  final void Function(Book)? onOpenBook;
  const _WelcomePane({required this.state, this.onOpenBook});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final currentlyReading = state.currentlyReading;

    if (state.books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 20),
            Text(l10n.libraryEmptyTitle,
                style: MokuText.sectionHeading()),
            const SizedBox(height: 8),
            Text(l10n.libraryEmptyBody,
                style: MokuText.body(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.read<LibraryCubit>().importBook(),
              icon: const Icon(Icons.file_open_rounded),
              label: Text(l10n.commonImportFiles),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentlyReading.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.play_circle_outline_rounded,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.libraryContinueReading,
                        style: MokuText.sectionHeading(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ContinueReadingGrid(
                    books: currentlyReading.take(6).toList(),
                    progressMap: state.progressMap,
                  ),
                  const SizedBox(height: 32),
                ],
                Row(
                  children: [
                    Text(
                      l10n.librarySectionTitle,
                      style: MokuText.sectionHeading(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.books.length}',
                      style: MokuText.caption(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a book from the sidebar to view details.',
                  style: MokuText.body(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueReadingGrid extends StatelessWidget {
  final List<Book> books;
  final Map<String, double> progressMap;

  const _ContinueReadingGrid({
    required this.books,
    required this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            final progress = progressMap[book.id] ?? 0.0;
            return InkWell(
              onTap: () {
                context.read<LibraryCubit>().selectBook(book.id);
              },
              borderRadius: BorderRadius.circular(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 64,
                          child:
                              BookCoverWidget(book: book, borderRadius: 6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              bookTitleLabel(context, book.title),
                              style: MokuText.bookTitleSmall(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Strips HTML tags and decodes common entities.
String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();
}
