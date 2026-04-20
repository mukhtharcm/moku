import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/book.dart';

/// Dedicated reader screen for PDF files using pdfrx.
class PdfReaderScreen extends StatefulWidget {
  final Book book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late PdfViewerController _controller;
  bool _showControls = true;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final database = context.read<db.AppDatabase>();
    final progress = await database.getProgressForBook(widget.book.id);
    if (progress != null && progress.currentChapter > 0) {
      // currentChapter stores the page number for PDFs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.goToPage(pageNumber: progress.currentChapter + 1);
      });
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = (prefs.getInt('reader_theme') ?? 0) == 1;
    });
  }

  Future<void> _saveProgress() async {
    if (!mounted) return;
    final database = context.read<db.AppDatabase>();
    final overall = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
    final now = DateTime.now();

    await database.upsertProgress(
      db.ReadingProgressesCompanion(
        id: Value(widget.book.id),
        bookId: Value(widget.book.id),
        currentChapter: Value(_currentPage - 1),
        chapterProgress: Value(0.0),
        overallProgress: Value(overall.clamp(0.0, 1.0)),
        lastReadAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  void dispose() {
    _saveProgress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = _darkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final fgColor = _darkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // PDF viewer
          PdfViewer.file(
            widget.book.filePath,
            controller: _controller,
            params: PdfViewerParams(
              backgroundColor: bgColor,
              onPageChanged: (pageNumber) {
                setState(() => _currentPage = pageNumber ?? 1);
                _saveProgress();
              },
              onViewerReady: (document, controller) {
                setState(() {
                  _totalPages = document.pages.length;
                  _currentPage = controller.pageNumber ?? 1;
                });
              },
            ),
          ),

          // Tap area to toggle controls
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _showControls = !_showControls),
              child: const SizedBox.shrink(),
            ),
          ),

          // Top bar
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColor.withValues(alpha: 0.95),
                      bgColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: fgColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          widget.book.title,
                          style: TextStyle(
                            color: fgColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _darkMode ? Icons.light_mode : Icons.dark_mode,
                          color: fgColor,
                        ),
                        onPressed: () {
                          setState(() => _darkMode = !_darkMode);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom bar with page slider
          if (_showControls && _totalPages > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      bgColor.withValues(alpha: 0.95),
                      bgColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page slider
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: fgColor.withValues(alpha: 0.2),
                          thumbColor: theme.colorScheme.primary,
                        ),
                        child: Slider(
                          value: _currentPage.toDouble(),
                          min: 1,
                          max: _totalPages.toDouble(),
                          onChanged: (value) {
                            final page = value.round();
                            _controller.goToPage(pageNumber: page);
                          },
                        ),
                      ),
                      // Page info
                      Text(
                        'Page $_currentPage of $_totalPages',
                        style: TextStyle(
                          color: fgColor.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
