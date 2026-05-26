import '../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/book.dart';
import '../../../core/models/book_localizations.dart';
import '../../../core/sync/auto_sync_service.dart';
import '../../../l10n/l10n.dart';

/// Dedicated reader screen for PDF files using pdfrx.
class PdfReaderScreen extends StatefulWidget {
  final Book book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen>
    with WidgetsBindingObserver {
  late PdfViewerController _controller;
  late final db.AppDatabase _database;
  late final AutoSyncService _autoSync;
  bool _showControls = true;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _darkMode = false;

  // Session tracking
  String? _sessionId;
  DateTime? _sessionStartedAt;
  int _sessionStartPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _database = context.read<db.AppDatabase>();
    _autoSync = context.read<AutoSyncService>();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _finalizeSession();
    } else if (state == AppLifecycleState.resumed) {
      _restartSession();
    }
  }

  Future<void> _loadProgress() async {
    final progress = await _database.getProgressForBook(widget.book.id);
    if (!mounted) return;

    if (progress != null && progress.currentChapter > 0) {
      // currentChapter stores the page number for PDFs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.goToPage(pageNumber: progress.currentChapter + 1);
      });
      _currentPage = progress.currentChapter + 1;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _darkMode = (prefs.getInt('reader_theme') ?? 0) == 1;
    });

    _beginSession();
  }

  void _beginSession() {
    _sessionId = const Uuid().v4();
    _sessionStartedAt = DateTime.now();
    _sessionStartPage = _currentPage - 1;
  }

  void _restartSession() {
    _finalizeSession();
    _beginSession();
  }

  Future<void> _saveProgress() async {
    final overall = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
    final now = DateTime.now();

    await _database.upsertProgress(
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
    // Frequent per-page call — use throttled progress bump.
    try {
      _autoSync.bumpProgress();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finalizeSession();
    _saveProgress();
    super.dispose();
  }

  Future<void> _finalizeSession() async {
    final sessionId = _sessionId;
    final startedAt = _sessionStartedAt;
    if (sessionId == null || startedAt == null) return;

    final endedAt = DateTime.now();
    final duration = endedAt.difference(startedAt).inSeconds;

    _sessionId = null;
    _sessionStartedAt = null;

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
        endChapter: Value(_currentPage - 1),
      ),
    );

    // Flush on reader close / pause so session lands promptly.
    try {
      _autoSync.flush();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bgColor = _darkMode ? MokuColors.nightBase : Colors.white;
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
                if (!mounted) return;
                setState(() => _currentPage = pageNumber ?? 1);
                _saveProgress();
              },
              onViewerReady: (document, controller) {
                if (!mounted) return;
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
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: fgColor),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          bookTitleLabel(context, widget.book.title),
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
                        tooltip: _darkMode
                            ? l10n.readerSwitchToLightMode
                            : l10n.readerSwitchToDarkMode,
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
                            enabledThumbRadius: 6,
                          ),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: fgColor.withValues(alpha: 0.2),
                          thumbColor: theme.colorScheme.primary,
                        ),
                        child: Semantics(
                          label: l10n.readerPageOf(
                            currentPage: _currentPage,
                            totalPages: _totalPages,
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
                      ),
                      // Page info
                      Text(
                        l10n.readerPageOf(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                        ),
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
