import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/bidi_text.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/models/book_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/services/path_resolver.dart';
import '../../../l10n/l10n.dart';
import '../cubit/collections_cubit.dart';
import '../../library/widgets/book_cover.dart';
import '../../library/widgets/book_grid_item.dart';
import '../../reader/screens/reader_screen.dart';

class CollectionDetailScreen extends StatefulWidget {
  final BookCollection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late Stream<List<db.Book>> _booksStream;

  @override
  void initState() {
    super.initState();
    _booksStream = context.read<db.AppDatabase>().watchBooksInCollection(
      widget.collection.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<db.Book>>(
      stream: _booksStream,
      builder: (context, snapshot) {
        final books = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.collection.name),
            actions: [
              if (snapshot.connectionState != ConnectionState.waiting &&
                  books.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.l10n.collectionDetailAddBooksTooltip,
                  onPressed: () => _showAddBooksDialog(context),
                ),
            ],
          ),
          body: switch (snapshot.connectionState) {
            ConnectionState.waiting => const Center(
              child: CircularProgressIndicator(),
            ),
            _ when books.isEmpty => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.collectionDetailEmptyTitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => _showAddBooksDialog(context),
                    child: Text(context.l10n.collectionDetailAddBooks),
                  ),
                ],
              ),
            ),
            _ => LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 900
                    ? 6
                    : constraints.maxWidth > 600
                        ? 4
                        : 3;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = _toBook(books[index]);
                    return BookGridItem(
                      book: book,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(book: book),
                          ),
                        );
                      },
                      onLongPress: () => _confirmRemove(context, book),
                    );
                  },
                );
              },
            ),
          },
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, Book book) {
    final l10n = context.l10n;
    final collectionsCubit = context.read<CollectionsCubit?>();
    final database = context.read<db.AppDatabase>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.collectionDetailRemoveTitle),
        content: Text(
          l10n.collectionDetailRemoveMessage(
            title: bidiWrappedText(
              context,
              bookTitleLabel(context, book.title),
            ),
            collectionName: bidiWrappedText(context, widget.collection.name),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              if (collectionsCubit != null) {
                await collectionsCubit.removeBookFromCollection(
                  widget.collection.id,
                  book.id,
                );
              } else {
                await database.removeBookFromCollection(
                  widget.collection.id,
                  book.id,
                );
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
  }

  void _showAddBooksDialog(BuildContext context) async {
    final database = context.read<db.AppDatabase>();
    final collectionsCubit = context.read<CollectionsCubit?>();
    final allBooks = await database.getAllBooks();
    final collectionBooks = await database.getBooksInCollection(
      widget.collection.id,
    );
    final collectionBookIds = collectionBooks.map((b) => b.id).toSet();

    final availableBooks = allBooks
        .where((b) => !collectionBookIds.contains(b.id))
        .toList();

    if (!context.mounted) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    if (availableBooks.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.collectionDetailAllBooksAlreadyAdded)),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final remainingBooks = List<db.Book>.of(availableBooks);

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> addBook(db.Book dbBook) async {
              final titleLabel = bookTitleLabel(sheetContext, dbBook.title);

              if (collectionsCubit != null) {
                await collectionsCubit.addBookToCollection(
                  widget.collection.id,
                  dbBook.id,
                );
              } else {
                await database.addBookToCollection(
                  widget.collection.id,
                  dbBook.id,
                );
              }
              if (!sheetContext.mounted) return;

              setSheetState(() {
                remainingBooks.removeWhere((book) => book.id == dbBook.id);
              });

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.collectionDetailAddedBook(
                      title: bidiWrappedText(sheetContext, titleLabel),
                    ),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );

              if (remainingBooks.isEmpty) {
                Navigator.of(sheetContext).pop();
              }
            }

            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Text(
                      l10n.collectionDetailAddBooksTitle,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: remainingBooks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (itemContext, index) {
                        final dbBook = remainingBooks[index];
                        final book = _toBook(dbBook);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          leading: SizedBox(
                            width: 40,
                            height: 60,
                            child: BookCoverWidget(book: book, borderRadius: 6),
                          ),
                          title: Text(
                            bookTitleLabel(itemContext, dbBook.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            bookAuthorLabel(itemContext, dbBook.author),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            Icons.add_circle_outline_rounded,
                            color: Theme.of(itemContext).colorScheme.primary,
                          ),
                          onTap: () => addBook(dbBook),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Book _toBook(db.Book dbBook) {
    return Book(
      id: dbBook.id,
      title: dbBook.title,
      author: dbBook.author,
      description: dbBook.description,
      coverPath: PathResolver.resolveNullable(dbBook.coverPath),
      filePath: PathResolver.resolve(dbBook.filePath),
      createdAt: dbBook.createdAt,
      updatedAt: dbBook.updatedAt,
    );
  }
}
