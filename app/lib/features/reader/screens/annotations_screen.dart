import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/book.dart';
import '../cubit/reader_cubit.dart';
import '../cubit/reader_state.dart';

class AnnotationsScreen extends StatefulWidget {
  final Book book;

  const AnnotationsScreen({super.key, required this.book});

  @override
  State<AnnotationsScreen> createState() => _AnnotationsScreenState();
}

class _AnnotationsScreenState extends State<AnnotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<db.Highlight> _allHighlights = [];
  List<db.Bookmark> _allBookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final cubit = context.read<ReaderCubit>();
    final database = cubit.database;
    final highlights = await database.getHighlightsForBook(widget.book.id);
    final bookmarks = await database.getBookmarksForBook(widget.book.id);
    setState(() {
      _allHighlights = highlights;
      _allBookmarks = bookmarks;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = context.watch<ReaderCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annotations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.highlight),
              text: 'Highlights (${_allHighlights.length})',
            ),
            Tab(
              icon: const Icon(Icons.bookmark),
              text: 'Bookmarks (${_allBookmarks.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHighlightsList(context, state, colorScheme),
                _buildBookmarksList(context, state, colorScheme),
              ],
            ),
    );
  }

  Widget _buildHighlightsList(
    BuildContext context,
    ReaderState state,
    ColorScheme colorScheme,
  ) {
    if (_allHighlights.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.highlight_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No highlights yet',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 4),
            Text('Select text while reading to highlight it',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    // Group by chapter
    final grouped = <int, List<db.Highlight>>{};
    for (final h in _allHighlights) {
      grouped.putIfAbsent(h.chapterIndex, () => []).add(h);
    }
    final sortedChapters = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedChapters.length,
      itemBuilder: (context, index) {
        final chapterIndex = sortedChapters[index];
        final highlights = grouped[chapterIndex]!;
        final chapterTitle = chapterIndex < state.chapters.length
            ? state.chapters[chapterIndex].title
            : 'Chapter ${chapterIndex + 1}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                chapterTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
            ...highlights.map((h) => _HighlightTile(
                  highlight: h,
                  onTap: () {
                    context.read<ReaderCubit>().goToChapter(h.chapterIndex);
                    Navigator.pop(context);
                  },
                  onDelete: () => _confirmDelete(context, h),
                  onEditNote: () => _editNote(context, h),
                )),
            if (index < sortedChapters.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }

  Widget _buildBookmarksList(
    BuildContext context,
    ReaderState state,
    ColorScheme colorScheme,
  ) {
    if (_allBookmarks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No bookmarks yet',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _allBookmarks.length,
      itemBuilder: (context, index) {
        final bm = _allBookmarks[index];
        final chapterTitle = bm.chapterIndex < state.chapters.length
            ? state.chapters[bm.chapterIndex].title
            : 'Chapter ${bm.chapterIndex + 1}';

        return ListTile(
          leading: Icon(Icons.bookmark, color: colorScheme.primary),
          title: Text(bm.title),
          subtitle: Text(chapterTitle, style: const TextStyle(fontSize: 12)),
          onTap: () {
            context.read<ReaderCubit>().goToChapter(bm.chapterIndex);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, db.Highlight highlight) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Highlight'),
        content: const Text('Are you sure you want to delete this highlight?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ReaderCubit>().deleteHighlight(highlight.id);
              _loadData();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editNote(BuildContext context, db.Highlight highlight) {
    final noteController = TextEditingController(text: highlight.note ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${highlight.selectedText}"',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'Enter your note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
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
              Navigator.pop(ctx);
              await context
                  .read<ReaderCubit>()
                  .updateHighlightNote(highlight.id, noteController.text);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final db.Highlight highlight;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEditNote;

  const _HighlightTile({
    required this.highlight,
    required this.onTap,
    required this.onDelete,
    required this.onEditNote,
  });

  Color _parseColor(String hex) {
    try {
      final hexStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$hexStr', radix: 16));
    } catch (_) {
      return const Color(0xFFFFEB3B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor = _parseColor(highlight.color);

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${highlight.selectedText}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (highlight.note != null && highlight.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.note, size: 14,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            highlight.note!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Edit Note'),
              onTap: () {
                Navigator.pop(ctx);
                onEditNote();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
