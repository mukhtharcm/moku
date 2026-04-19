import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/models.dart';
import '../../../core/services/epub_service.dart';
import '../../../core/theme/app_theme.dart';
import 'reader_state.dart';

class ReaderCubit extends Cubit<ReaderState> {
  final db.AppDatabase _database;
  final EpubService _epubService;
  static const _uuid = Uuid();

  ReaderCubit({
    required db.AppDatabase database,
    required EpubService epubService,
    required Book book,
  })  : _database = database,
        _epubService = epubService,
        super(ReaderState(book: book));

  db.AppDatabase get database => _database;

  Future<void> loadBook() async {
    emit(state.copyWith(status: ReaderStatus.loading));

    try {
      // Load reader preferences
      final prefs = await SharedPreferences.getInstance();
      final fontSize = prefs.getDouble('reader_font_size') ?? 18.0;
      final themeIndex = prefs.getInt('reader_theme') ?? 0;

      // Get chapters
      final chapters = await _epubService.getChapters(state.book.filePath);

      // Load saved progress
      final progress = await _database.getProgressForBook(state.book.id);
      final startChapter = progress?.currentChapter ?? 0;

      // Load first chapter content
      final content = await _epubService.getChapterContent(
        state.book.filePath,
        startChapter,
      );

      emit(state.copyWith(
        status: ReaderStatus.loaded,
        chapters: chapters,
        currentChapter: startChapter,
        currentContent: content,
        fontSize: fontSize,
        readerTheme: ReaderTheme.values[themeIndex.clamp(0, ReaderTheme.values.length - 1)],
        scrollProgress: progress?.chapterProgress ?? 0.0,
      ));

      await loadHighlightsForChapter();
    } catch (e) {
      emit(state.copyWith(
        status: ReaderStatus.error,
        errorMessage: 'Failed to load book: $e',
      ));
    }
  }

  Future<void> goToChapter(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;

    try {
      final content = await _epubService.getChapterContent(
        state.book.filePath,
        chapterIndex,
      );

      emit(state.copyWith(
        currentChapter: chapterIndex,
        currentContent: content,
        scrollProgress: 0.0,
        showToc: false,
      ));

      await _saveProgress();
      await loadHighlightsForChapter();
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to load chapter: $e',
      ));
    }
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

  void toggleControls() {
    emit(state.copyWith(showControls: !state.showControls));
  }

  void toggleToc() {
    emit(state.copyWith(showToc: !state.showToc));
  }

  void toggleZenMode() {
    final entering = !state.zenMode;
    emit(state.copyWith(
      zenMode: entering,
      showControls: false,
      showToc: false,
    ));
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(12.0, 32.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', clamped);
    emit(state.copyWith(fontSize: clamped));
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
        : (state.currentChapter + state.scrollProgress) /
            state.chapters.length;

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
  }

  // --- Highlight methods ---

  Future<void> loadHighlightsForChapter() async {
    final highlights = await _database.getHighlightsForChapter(
      state.book.id,
      state.currentChapter,
    );
    emit(state.copyWith(highlights: highlights));
  }

  Future<void> addHighlight(String selectedText, int startOffset, int endOffset) async {
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
    await loadHighlightsForChapter();
  }

  Future<void> deleteHighlight(String id) async {
    await _database.deleteHighlight(id);
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
    await loadHighlightsForChapter();
  }
}
