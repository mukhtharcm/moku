import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/models.dart';
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
    _booksStream = context
        .read<db.AppDatabase>()
        .watchBooksInCollection(widget.collection.id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add books',
            onPressed: () => _showAddBooksDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<db.Book>>(
        stream: _booksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data ?? [];

          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_books_outlined,
                      size: 64,
                      color: colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No books in this collection',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => _showAddBooksDialog(context),
                    child: const Text('Add Books'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final dbBook = books[index];
              final book = Book(
                id: dbBook.id,
                title: dbBook.title,
                author: dbBook.author,
                description: dbBook.description,
                coverPath: dbBook.coverPath,
                filePath: dbBook.filePath,
                createdAt: dbBook.createdAt,
                updatedAt: dbBook.updatedAt,
              );

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
    );
  }

  void _confirmRemove(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Collection'),
        content: Text(
            'Remove "${book.title}" from "${widget.collection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<db.AppDatabase>().removeBookFromCollection(
                    widget.collection.id,
                    book.id,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddBooksDialog(BuildContext context) async {
    final database = context.read<db.AppDatabase>();
    final allBooks = await database.getAllBooks();
    final collectionBooks =
        await database.getBooksInCollection(widget.collection.id);
    final collectionBookIds = collectionBooks.map((b) => b.id).toSet();

    final availableBooks =
        allBooks.where((b) => !collectionBookIds.contains(b.id)).toList();

    if (!context.mounted) return;

    if (availableBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All books are already in this collection')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add Books',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: availableBooks.length,
                itemBuilder: (context, index) {
                  final dbBook = availableBooks[index];
                  final book = Book(
                    id: dbBook.id,
                    title: dbBook.title,
                    author: dbBook.author,
                    coverPath: dbBook.coverPath,
                    filePath: dbBook.filePath,
                    createdAt: dbBook.createdAt,
                    updatedAt: dbBook.updatedAt,
                  );

                  return ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 60,
                      child: BookCoverWidget(book: book, borderRadius: 6),
                    ),
                    title: Text(dbBook.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(dbBook.author,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () async {
                        await database.addBookToCollection(
                          widget.collection.id,
                          dbBook.id,
                        );
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Added "${dbBook.title}"'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
