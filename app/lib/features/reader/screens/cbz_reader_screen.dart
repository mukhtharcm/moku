import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/formats/cbz/cbz_parser.dart';
import '../../../core/models/book.dart';
import '../../../core/sync/auto_sync_service.dart';

/// Dedicated reader screen for CBZ (Comic Book ZIP) files.
///
/// Displays images in a full-screen page viewer with swipe navigation.
class CbzReaderScreen extends StatefulWidget {
  final Book book;

  const CbzReaderScreen({super.key, required this.book});

  @override
  State<CbzReaderScreen> createState() => _CbzReaderScreenState();
}

class _CbzReaderScreenState extends State<CbzReaderScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _showControls = true;
  bool _isLoading = true;
  final Map<int, Uint8List> _imageCache = {};

  late final db.AppDatabase _database;

  // Session tracking
  String? _sessionId;
  DateTime? _sessionStartedAt;
  int _sessionStartPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _database = context.read<db.AppDatabase>();
    WidgetsBinding.instance.addObserver(this);
    _loadComic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _finalizeSession();
    } else if (state == AppLifecycleState.resumed) {
      _restartSession();
    }
  }

  Future<void> _loadComic() async {
    final pageCount = await CbzParser.getPageCount(widget.book.filePath);

    // Load saved progress
    final progress = await _database.getProgressForBook(widget.book.id);
    final startPage = progress?.currentChapter ?? 0;

    setState(() {
      _totalPages = pageCount;
      _currentPage = startPage.clamp(0, pageCount - 1);
      _isLoading = false;
    });

    if (_currentPage > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(_currentPage);
      });
    }

    // Start reading session now that we know the page
    _beginSession();

    // Pre-load first few pages
    _preloadPages(_currentPage);
  }

  void _beginSession() {
    _sessionId = const Uuid().v4();
    _sessionStartedAt = DateTime.now();
    _sessionStartPage = _currentPage;
  }

  void _restartSession() {
    _finalizeSession();
    _beginSession();
  }

  Future<void> _preloadPages(int centerPage) async {
    for (int i = centerPage; i < (centerPage + 3).clamp(0, _totalPages); i++) {
      if (!_imageCache.containsKey(i)) {
        final data = await CbzParser.getPageImage(widget.book.filePath, i);
        if (mounted) setState(() => _imageCache[i] = data);
      }
    }
  }

  Future<void> _saveProgress() async {
    if (!mounted) return;
    final overall = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
    final now = DateTime.now();

    await _database.upsertProgress(
      db.ReadingProgressesCompanion(
        id: Value(widget.book.id),
        bookId: Value(widget.book.id),
        currentChapter: Value(_currentPage),
        chapterProgress: Value(0.0),
        overallProgress: Value(overall.clamp(0.0, 1.0)),
        lastReadAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    try {
      context.read<AutoSyncService>().bumpProgress();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finalizeSession();
    _saveProgress();
    CbzParser.clearCache(widget.book.filePath);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finalizeSession() async {
    final sessionId = _sessionId;
    final startedAt = _sessionStartedAt;
    if (sessionId == null || startedAt == null) return;

    final endedAt = DateTime.now();
    final duration = endedAt.difference(startedAt).inSeconds;
    if (duration < 30) return;

    await _database.insertSession(
      db.ReadingSessionsCompanion.insert(
        id: sessionId,
        bookId: widget.book.id,
        bookTitle: widget.book.title,
        startedAt: startedAt,
        endedAt: Value(endedAt),
        durationSeconds: Value(duration),
        startChapter: Value(_sessionStartPage),
        endChapter: Value(_currentPage),
      ),
    );

    _sessionId = null;
    _sessionStartedAt = null;
    try {
      context.read<AutoSyncService>().flush();
    } catch (_) {}
  }

  Widget _buildPage(int index) {
    if (_imageCache.containsKey(index)) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            _imageCache[index]!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    // Load image asynchronously
    return FutureBuilder<Uint8List>(
      future: CbzParser.getPageImage(widget.book.filePath, index),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _imageCache[index] = snapshot.data!;
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bgColor = Colors.black;
    const fgColor = Colors.white;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Page viewer
          PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _preloadPages(page);
              _saveProgress();
            },
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: _buildPage(index),
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
                      bgColor.withValues(alpha: 0.9),
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
                        icon: const Icon(Icons.arrow_back, color: fgColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          widget.book.title,
                          style: const TextStyle(
                            color: fgColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                      bgColor.withValues(alpha: 0.9),
                      bgColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: fgColor.withValues(alpha: 0.3),
                          thumbColor: theme.colorScheme.primary,
                        ),
                        child: Slider(
                          value: (_currentPage + 1).toDouble(),
                          min: 1,
                          max: _totalPages.toDouble(),
                          onChanged: (value) {
                            final page = value.round() - 1;
                            _pageController.jumpToPage(page);
                          },
                        ),
                      ),
                      Text(
                        'Page ${_currentPage + 1} of $_totalPages',
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
