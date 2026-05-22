import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/book.dart';
import '../../../l10n/l10n.dart';
import '../reader_localizations.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.readerAnnotations),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.highlight),
              text: l10n.readerHighlightsTab(count: _allHighlights.length),
            ),
            Tab(
              icon: const Icon(Icons.bookmark),
              text: l10n.readerBookmarksTab(count: _allBookmarks.length),
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
      final l10n = context.l10n;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.highlight_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              l10n.readerNoHighlightsYet,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.readerNoHighlightsHint,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
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
        final chapterTitle = readerChapterTitle(context, state, chapterIndex);

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
            ...highlights.map(
              (h) => _HighlightTile(
                highlight: h,
                onTap: () {
                  context.read<ReaderCubit>().goToHighlight(
                    h.chapterIndex,
                    h.selectedText,
                  );
                  Navigator.pop(context);
                },
                onDelete: () => _confirmDelete(context, h),
                onEditNote: () => _editNote(context, h),
              ),
            ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              context.l10n.readerNoBookmarksYet,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _allBookmarks.length,
      itemBuilder: (context, index) {
        final bm = _allBookmarks[index];
        final chapterTitle = readerChapterTitle(
          context,
          state,
          bm.chapterIndex,
        );

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
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.readerDeleteHighlightTitle),
        content: Text(l10n.readerDeleteHighlightMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ReaderCubit>().deleteHighlight(highlight.id);
              _loadData();
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _editNote(BuildContext context, db.Highlight highlight) {
    final noteController = TextEditingController(text: highlight.note ?? '');
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.readerEditNote),
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
              decoration: InputDecoration(
                hintText: l10n.readerNoteHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ReaderCubit>().updateHighlightNote(
                highlight.id,
                noteController.text,
              );
              _loadData();
            },
            child: Text(l10n.commonSave),
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
                        Icon(
                          Icons.note,
                          size: 14,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            highlight.note!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(l10n.readerEditNote),
              onTap: () {
                Navigator.pop(ctx);
                onEditNote();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                l10n.commonDelete,
                style: const TextStyle(color: Colors.red),
              ),
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
