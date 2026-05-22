import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/models.dart';
import '../../../core/services/book_service.dart';
import '../../../core/sync/auto_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import 'reader_state.dart';

class ReaderCubit extends Cubit<ReaderState> {
  final db.AppDatabase _database;
  final BookService _bookService;
  final AutoSyncService? _autoSync;
  static const _uuid = Uuid();

  String? _currentSessionId;
  DateTime? _sessionStartedAt;
  int _sessionStartChapter = 0;

  ReaderCubit({
    required db.AppDatabase database,
    required BookService bookService,
    required Book book,
    AutoSyncService? autoSync,
  }) : _database = database,
       _bookService = bookService,
       _autoSync = autoSync,
       super(ReaderState(book: book));

  db.AppDatabase get database => _database;

  Future<void> loadBook() async {
    emit(state.copyWith(status: ReaderStatus.loading));

    try {
      // Load reader preferences
      final prefs = await SharedPreferences.getInstance();
      final fontSize = prefs.getDouble('reader_font_size') ?? 18.0;
      final lineHeight = prefs.getDouble('reader_line_height') ?? 1.8;
      final margin = prefs.getDouble('reader_margin') ?? 24.0;
      final themeIndex = prefs.getInt('reader_theme') ?? 0;
      final fontFamilyIndex = prefs.getInt('reader_font_family') ?? 0;

      // Get spine items (reading order)
      final chapters = await _bookService.getChapters(
        state.book.filePath,
        state.book.format,
      );

      // Load saved progress
      final progress = await _database.getProgressForBook(state.book.id);
      final startChapter = progress?.currentChapter ?? 0;
      final safeStartChapter = startChapter.clamp(
        0,
        chapters.isEmpty ? 0 : chapters.length - 1,
      );

      // Load content (only for WebView-based formats)
      String content = '';
      if (state.book.format == BookFormat.epub ||
          state.book.format == BookFormat.txt ||
          state.book.format == BookFormat.html) {
        content = await _bookService.getChapterContent(
          state.book.filePath,
          state.book.format,
          safeStartChapter,
        );
      }

      emit(
        state.copyWith(
          status: ReaderStatus.loaded,
          chapters: chapters,
          currentChapter: safeStartChapter,
          currentContent: content,
          fontSize: fontSize,
          lineHeight: lineHeight,
          horizontalMargin: margin,
          fontFamily:
              ReaderFontFamily.values[fontFamilyIndex.clamp(
                0,
                ReaderFontFamily.values.length - 1,
              )],
          readerTheme: ReaderTheme
              .values[themeIndex.clamp(0, ReaderTheme.values.length - 1)],
          scrollProgress: progress?.chapterProgress ?? 0.0,
        ),
      );

      await loadHighlightsForChapter();
      _beginSession();
    } catch (e) {
      emit(state.copyWith(status: ReaderStatus.error, errorMessage: '$e'));
    }
  }

  void _beginSession() {
    _currentSessionId = _uuid.v4();
    _sessionStartedAt = DateTime.now();
    _sessionStartChapter = state.currentChapter;
  }

  /// Called when the app returns to the foreground mid-reading.
  Future<void> restartSession() async {
    await finalizeSession();
    _beginSession();
  }

  Future<void> finalizeSession() async {
    final sessionId = _currentSessionId;
    final startedAt = _sessionStartedAt;
    if (sessionId == null || startedAt == null) return;

    final endedAt = DateTime.now();
    final duration = endedAt.difference(startedAt).inSeconds;
    if (duration < 30) return; // Ignore very short sessions

    await _database.insertSession(
      db.ReadingSessionsCompanion.insert(
        id: sessionId,
        bookId: state.book.id,
        bookTitle: state.book.title,
        startedAt: startedAt,
        endedAt: Value(endedAt),
        durationSeconds: Value(duration),
        startChapter: Value(_sessionStartChapter),
        endChapter: Value(state.currentChapter),
      ),
    );
    _currentSessionId = null;
    _sessionStartedAt = null;
    // Flush immediately so the reader session lands on the server without
    // waiting for the next periodic tick.
    _autoSync?.flush();
  }

  Future<void> goToChapter(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;

    try {
      String content = '';
      if (state.book.format == BookFormat.epub ||
          state.book.format == BookFormat.txt ||
          state.book.format == BookFormat.html) {
        content = await _bookService.getChapterContent(
          state.book.filePath,
          state.book.format,
          chapterIndex,
        );
      }

      emit(
        state.copyWith(
          currentChapter: chapterIndex,
          currentContent: content,
          scrollProgress: 0.0,
          showToc: false,
        ),
      );

      await _saveProgress();
      await loadHighlightsForChapter();
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
    }
  }

  /// Navigate to a specific highlight's location (chapter + text)
  Future<void> goToHighlight(int chapterIndex, String selectedText) async {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;

    try {
      if (chapterIndex != state.currentChapter) {
        String content = '';
        if (state.book.format == BookFormat.epub ||
            state.book.format == BookFormat.txt ||
            state.book.format == BookFormat.html) {
          content = await _bookService.getChapterContent(
            state.book.filePath,
            state.book.format,
            chapterIndex,
          );
        }
        emit(
          state.copyWith(
            currentChapter: chapterIndex,
            currentContent: content,
            scrollProgress: 0.0,
            showToc: false,
            pendingHighlightText: selectedText,
          ),
        );
        await _saveProgress();
        await loadHighlightsForChapter();
      } else {
        // Same chapter — just signal to scroll to highlight
        emit(state.copyWith(pendingHighlightText: selectedText));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
    }
  }

  void clearPendingHighlight() {
    emit(state.copyWith(clearPendingHighlight: true));
  }

  Future<void> nextChapter() async {
    if (state.hasNextChapter) {
      await goToChapter(state.currentChapter + 1);
    }
  }

  Future<void> previousChapter() async {
    if (state.hasPreviousChapter) {
      await goToChapter(state.currentChapter - 1);
    }
  }

  Future<void> updateScrollProgress(double progress) async {
    emit(state.copyWith(scrollProgress: progress));
    await _saveProgress();
  }

  void updatePageInfo(int page, int total) {
    final progress = total > 1 ? page / (total - 1) : 0.0;
    emit(
      state.copyWith(
        currentPage: page,
        totalPages: total,
        scrollProgress: progress.clamp(0.0, 1.0),
      ),
    );
    _saveProgress();
  }

  void toggleControls() {
    emit(state.copyWith(showControls: !state.showControls));
  }

  void toggleToc() {
    emit(state.copyWith(showToc: !state.showToc));
  }

  void toggleZenMode() {
    final entering = !state.zenMode;
    emit(
      state.copyWith(zenMode: entering, showControls: false, showToc: false),
    );
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(12.0, 32.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', clamped);
    emit(state.copyWith(fontSize: clamped));
  }

  Future<void> setLineHeight(double height) async {
    final clamped = height.clamp(1.2, 3.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_line_height', clamped);
    emit(state.copyWith(lineHeight: clamped));
  }

  Future<void> setHorizontalMargin(double margin) async {
    final clamped = margin.clamp(8.0, 48.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_margin', clamped);
    emit(state.copyWith(horizontalMargin: clamped));
  }

  Future<void> setFontFamily(ReaderFontFamily family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'reader_font_family',
      ReaderFontFamily.values.indexOf(family),
    );
    emit(state.copyWith(fontFamily: family));
  }

  Future<void> setReaderTheme(ReaderTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final index = ReaderTheme.values.indexOf(theme);
    await prefs.setInt('reader_theme', index);
    emit(state.copyWith(readerTheme: theme));
  }

  Future<void> _saveProgress() async {
    final overallProgress = state.chapters.isEmpty
        ? 0.0
        : (state.currentChapter + state.scrollProgress) / state.chapters.length;

    final now = DateTime.now();
    await _database.upsertProgress(
      db.ReadingProgressesCompanion(
        id: Value(state.book.id),
        bookId: Value(state.book.id),
        currentChapter: Value(state.currentChapter),
        chapterProgress: Value(state.scrollProgress),
        overallProgress: Value(overallProgress.clamp(0.0, 1.0)),
        lastReadAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    // Progress updates come as often as every page turn. Use the throttled
    // progress bump (min 3 min interval, flushed on close/pause) rather
    // than the general 30s-debounce bump to avoid a sync storm.
    _autoSync?.bumpProgress();
  }

  Future<void> addBookmark(String title) async {
    final now = DateTime.now();
    await _database.insertBookmark(
      db.BookmarksCompanion.insert(
        id: _uuid.v4(),
        bookId: state.book.id,
        chapterIndex: state.currentChapter,
        title: title,
        createdAt: now,
      ),
    );
    _autoSync?.bump();
  }

  // --- Highlight methods ---

  Future<void> loadHighlightsForChapter() async {
    final highlights = await _database.getHighlightsForChapter(
      state.book.id,
      state.currentChapter,
    );
    emit(state.copyWith(highlights: highlights));
  }

  Future<void> addHighlight(
    String selectedText,
    int startOffset,
    int endOffset,
  ) async {
    final now = DateTime.now();
    await _database.insertHighlight(
      db.HighlightsCompanion.insert(
        id: _uuid.v4(),
        bookId: state.book.id,
        chapterIndex: state.currentChapter,
        selectedText: selectedText,
        startCfi: Value('offset:$startOffset'),
        endCfi: Value('offset:$endOffset'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    _autoSync?.bump();
    await loadHighlightsForChapter();
  }

  Future<void> deleteHighlight(String id) async {
    await _database.deleteHighlight(id);
    _autoSync?.bump();
    await loadHighlightsForChapter();
  }

  Future<void> updateHighlightNote(String id, String note) async {
    final highlightIndex = state.highlights.indexWhere((h) => h.id == id);
    if (highlightIndex == -1) return;
    final highlight = state.highlights[highlightIndex];
    await _database.updateHighlight(
      db.HighlightsCompanion(
        id: Value(highlight.id),
        bookId: Value(highlight.bookId),
        chapterIndex: Value(highlight.chapterIndex),
        startCfi: Value(highlight.startCfi),
        endCfi: Value(highlight.endCfi),
        selectedText: Value(highlight.selectedText),
        color: Value(highlight.color),
        note: Value(note),
        createdAt: Value(highlight.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _autoSync?.bump();
    await loadHighlightsForChapter();
  }

  @override
  Future<void> close() {
    _bookService.closeBook(state.book.filePath, state.book.format);
    // Ensure the reader's last progress hits the server.
    _autoSync?.flush();
    return super.close();
  }
}
