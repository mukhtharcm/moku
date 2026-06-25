import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../../core/ui/ui.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/models/book.dart';
import '../../../core/models/book_localizations.dart';
import '../../../core/sync/auto_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';

/// Dedicated reader screen for PDF files using pdfrx.
class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final VoidCallback? onClose;

  const PdfReaderScreen({super.key, required this.book, this.onClose});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen>
    with WidgetsBindingObserver, WindowListener {
  late PdfViewerController _controller;
  late final FocusNode _keyboardFocus;
  late final db.AppDatabase _database;
  late final AutoSyncService _autoSync;
  bool _showControls = true;
  int _currentPage = 1;
  int _totalPages = 0;
  ReaderTheme _readerTheme = ReaderTheme.light;
  _PdfViewMode _viewMode = _PdfViewMode.fitContent;
  bool _bookmarkConfirmed = false;
  bool _zenMode = false;
  bool _sidebarVisible = false;
  List<db.Bookmark> _bookmarks = [];
  final Map<int, PdfRect?> _contentRectCache = {};
  final Set<int> _fitPageFallbackPages = {};
  int _viewApplyEpoch = 0;
  int _viewerRebuildEpoch = 0;
  int? _pendingInitialPage;
  double _titleBarHeight =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? 28.0 : 0.0;
  double _windowedTitleBarHeight =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? 28.0 : 0.0;

  // Session tracking
  String? _sessionId;
  DateTime? _sessionStartedAt;
  int _sessionStartPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _keyboardFocus = FocusNode();
    _database = context.read<db.AppDatabase>();
    _autoSync = context.read<AutoSyncService>();
    WidgetsBinding.instance.addObserver(this);
    if (_isNativeDesktop) {
      windowManager.addListener(this);
      _syncTitleBarHeight();
    }
    _loadBookmarks();
    _loadProgress();
  }

  bool get _isNativeDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  bool get _usesDesktopChrome => _isNativeDesktop;

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
      // currentChapter stores the zero-based page index for PDFs.
      final savedPage = progress.currentChapter + 1;
      _pendingInitialPage = savedPage;
      setState(() => _currentPage = savedPage);
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final themeIndex = prefs.getInt('reader_theme') ?? 0;
    final viewModeIndex =
        prefs.getInt('pdf_reader_view_mode_${widget.book.id}') ??
        _PdfViewMode.fitContent.index;
    setState(() {
      _readerTheme = ReaderTheme
          .values[themeIndex.clamp(0, ReaderTheme.values.length - 1)];
      _viewMode = _PdfViewMode
          .values[viewModeIndex.clamp(0, _PdfViewMode.values.length - 1)];
    });

    _beginSession();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _database.getBookmarksForBook(widget.book.id);
    if (!mounted) return;
    setState(() => _bookmarks = bookmarks);
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
    if (_isNativeDesktop) {
      windowManager.removeListener(this);
    }
    _keyboardFocus.dispose();
    _finalizeSession();
    _saveProgress();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _contentRectCache.clear();
    _fitPageFallbackPages.clear();
    _scheduleApplyViewMode(duration: Duration.zero);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _titleBarHeight = 0);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _titleBarHeight = _windowedTitleBarHeight);
    Future.delayed(MokuMotion.normal, _syncTitleBarHeight);
  }

  Future<void> _syncTitleBarHeight() async {
    if (!_isNativeDesktop) return;
    try {
      final h = await windowManager.getTitleBarHeight();
      if (!mounted) return;
      if (h > 0) {
        _windowedTitleBarHeight = h.toDouble();
        if (_titleBarHeight != h.toDouble()) {
          setState(() => _titleBarHeight = h.toDouble());
        }
      }
    } catch (_) {}
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

  void _closeReader() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _setReaderTheme(ReaderTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reader_theme', ReaderTheme.values.indexOf(theme));
    if (!mounted) return;
    setState(() => _readerTheme = theme);
  }

  Future<void> _setViewMode(_PdfViewMode mode) async {
    final modeChanged = _viewMode != mode;
    if (mounted && modeChanged) {
      setState(() {
        _viewMode = mode;
        _viewerRebuildEpoch++;
      });
    }
    _scheduleApplyViewMode(
      duration: modeChanged ? Duration.zero : MokuMotion.fast,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pdf_reader_view_mode_${widget.book.id}', mode.index);
  }

  void _setZenMode(bool enabled) {
    if (_zenMode == enabled) return;
    _viewApplyEpoch++;
    setState(() {
      _zenMode = enabled;
      _viewerRebuildEpoch++;
    });
    _scheduleApplyViewMode(duration: Duration.zero);
  }

  void _scheduleApplyViewMode({Duration duration = MokuMotion.fast}) {
    final epoch = ++_viewApplyEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || epoch != _viewApplyEpoch) return;

      for (var attempt = 0; attempt < 10; attempt++) {
        if (!mounted || epoch != _viewApplyEpoch) return;
        if (_controller.isReady) break;
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (!mounted || epoch != _viewApplyEpoch || !_controller.isReady) return;
      await _applyViewMode(duration: duration, epoch: epoch);
    });
  }

  Future<void> _addBookmark() async {
    final now = DateTime.now();
    await _database.insertBookmark(
      db.BookmarksCompanion.insert(
        id: const Uuid().v4(),
        bookId: widget.book.id,
        chapterIndex: _currentPage - 1,
        title: 'Page $_currentPage',
        createdAt: now,
        updatedAt: Value(now),
      ),
    );
    try {
      _autoSync.bump();
    } catch (_) {}
    await _loadBookmarks();
    if (!mounted) return;
    setState(() => _bookmarkConfirmed = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _bookmarkConfirmed = false);
    });
  }

  bool _canApplyViewEpoch(int? epoch) {
    return mounted &&
        _controller.isReady &&
        (epoch == null || epoch == _viewApplyEpoch);
  }

  Future<void> _fitWidth({
    Duration duration = MokuMotion.fast,
    int? epoch,
  }) async {
    if (!_canApplyViewEpoch(epoch)) return;
    final matrix = _controller.calcMatrixFitWidthForPage(
      pageNumber: _currentPage,
    );
    if (!_canApplyViewEpoch(epoch)) return;
    await _controller.goTo(matrix, duration: duration);
  }

  Future<void> _fitPage({
    Duration duration = MokuMotion.fast,
    int? epoch,
  }) async {
    if (!_canApplyViewEpoch(epoch)) return;
    await _controller.goTo(
      _controller.calcMatrixForFit(pageNumber: _currentPage),
      duration: duration,
    );
  }

  Future<void> _fitActualSize({
    Duration duration = MokuMotion.fast,
    int? epoch,
  }) async {
    if (!_canApplyViewEpoch(epoch)) return;
    final pageNumber = _currentPage.clamp(1, math.max(_totalPages, 1)).toInt();
    final page = _controller.layout.pageLayouts[pageNumber - 1];
    final topCenter = Offset(
      page.center.dx,
      page.top + _controller.viewSize.height / 2,
    );
    if (!_canApplyViewEpoch(epoch)) return;
    await _controller.goTo(
      _controller.calcMatrixFor(topCenter, zoom: 1),
      duration: duration,
    );
  }

  Future<void> _fitContent({
    Duration duration = MokuMotion.fast,
    int? epoch,
  }) async {
    if (!_canApplyViewEpoch(epoch)) return;
    final pageNumber = _currentPage.clamp(1, math.max(_totalPages, 1)).toInt();
    final document = await _controller.useDocument((document) => document);
    if (!_canApplyViewEpoch(epoch)) return;
    if (document == null || pageNumber > document.pages.length) {
      await _fitWidth(duration: duration, epoch: epoch);
      return;
    }

    final contentRect = _contentRectCache[pageNumber] ??=
        await _detectContentRect(document.pages[pageNumber - 1]);
    if (contentRect == null || !_canApplyViewEpoch(epoch)) {
      if (_fitPageFallbackPages.contains(pageNumber)) {
        await _fitPage(duration: duration, epoch: epoch);
      } else {
        await _fitWidth(duration: duration, epoch: epoch);
      }
      return;
    }

    final page = document.pages[pageNumber - 1];
    final pageLayout = _controller.layout.pageLayouts[pageNumber - 1];
    final contentArea = contentRect
        .toRect(page: page, scaledPageSize: pageLayout.size)
        .translate(pageLayout.left, pageLayout.top);

    const viewportMargin = 28.0;
    final usableWidth = math.max(
      120.0,
      _controller.viewSize.width - viewportMargin * 2,
    );
    final zoom = (usableWidth / contentArea.width).clamp(
      _controller.minScale,
      _controller.params.maxScale,
    );
    final y =
        contentArea.top +
        (viewportMargin + _controller.viewSize.height / 2) / zoom;
    final matrix = _controller.calcMatrixFor(
      Offset(contentArea.center.dx, y),
      zoom: zoom,
    );
    if (!_canApplyViewEpoch(epoch)) return;
    await _controller.goTo(matrix, duration: duration);
  }

  Future<void> _applyViewMode({
    Duration duration = MokuMotion.fast,
    int? epoch,
  }) async {
    switch (_viewMode) {
      case _PdfViewMode.fitContent:
        await _fitContent(duration: duration, epoch: epoch);
        return;
      case _PdfViewMode.fitWidth:
        await _fitWidth(duration: duration, epoch: epoch);
        return;
      case _PdfViewMode.fitPage:
        await _fitPage(duration: duration, epoch: epoch);
        return;
      case _PdfViewMode.actualSize:
        await _fitActualSize(duration: duration, epoch: epoch);
        return;
    }
  }

  Future<PdfRect?> _detectContentRect(PdfPage page) async {
    if (page.pageNumber <= 3 && await _looksLikeGraphicPage(page)) {
      _fitPageFallbackPages.add(page.pageNumber);
      return null;
    }

    final textRect = await _detectTextContentRect(page);
    if (textRect != null) return textRect;
    return _detectImageContentRect(page);
  }

  Future<bool> _looksLikeGraphicPage(PdfPage page) async {
    final renderWidth = math.min(280, math.max(160, page.width.round()));
    final renderHeight = math.max(
      1,
      (renderWidth * page.height / page.width).round(),
    );
    PdfImage? image;
    try {
      image = await page.render(
        fullWidth: renderWidth.toDouble(),
        fullHeight: renderHeight.toDouble(),
        backgroundColor: Colors.white,
        annotationRenderingMode: PdfAnnotationRenderingMode.none,
        flags: PdfPageRenderFlags.grayscale,
      );
      if (image == null) return false;

      final pixels = image.pixels;
      final isBgra = image.format == ui.PixelFormat.bgra8888;
      var inkPixels = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        final c0 = pixels[i];
        final c1 = pixels[i + 1];
        final c2 = pixels[i + 2];
        final alpha = pixels[i + 3];
        final r = isBgra ? c2 : c0;
        final g = c1;
        final b = isBgra ? c0 : c2;
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        if (alpha > 24 && luminance < 238) inkPixels++;
      }
      final inkCoverage = inkPixels / (image.width * image.height);
      return inkCoverage > 0.22;
    } catch (_) {
      return false;
    } finally {
      image?.dispose();
    }
  }

  Future<PdfRect?> _detectTextContentRect(PdfPage page) async {
    try {
      final text = await page.loadText();
      PdfRect? bounds;
      for (final fragment in text.fragments) {
        if (fragment.text.trim().isEmpty || fragment.bounds.isEmpty) continue;
        bounds = bounds == null
            ? fragment.bounds
            : bounds.merge(fragment.bounds);
      }
      if (bounds == null) return null;
      if (bounds.width < page.width * 0.18 ||
          bounds.height < page.height * 0.05) {
        return null;
      }
      return _inflatePdfRectClamped(
        bounds,
        page,
        horizontal: page.width * 0.035,
        vertical: page.height * 0.025,
      );
    } catch (_) {
      return null;
    }
  }

  Future<PdfRect?> _detectImageContentRect(PdfPage page) async {
    final renderWidth = math.min(420, math.max(180, page.width.round()));
    final renderHeight = math.max(
      1,
      (renderWidth * page.height / page.width).round(),
    );
    PdfImage? image;
    try {
      image = await page.render(
        fullWidth: renderWidth.toDouble(),
        fullHeight: renderHeight.toDouble(),
        backgroundColor: Colors.white,
        annotationRenderingMode: PdfAnnotationRenderingMode.none,
        flags: PdfPageRenderFlags.grayscale,
      );
      if (image == null) return null;

      final colCounts = List<int>.filled(image.width, 0);
      final rowCounts = List<int>.filled(image.height, 0);
      final pixels = image.pixels;
      final isBgra = image.format == ui.PixelFormat.bgra8888;
      var inkPixels = 0;

      for (var y = 0; y < image.height; y++) {
        final row = y * image.width * 4;
        for (var x = 0; x < image.width; x++) {
          final offset = row + x * 4;
          final c0 = pixels[offset];
          final c1 = pixels[offset + 1];
          final c2 = pixels[offset + 2];
          final alpha = pixels[offset + 3];
          final r = isBgra ? c2 : c0;
          final g = c1;
          final b = isBgra ? c0 : c2;
          final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
          if (alpha > 24 && luminance < 238) {
            inkPixels++;
            colCounts[x]++;
            rowCounts[y]++;
          }
        }
      }

      final minColumnInk = math.max(2, (image.height * 0.003).round());
      final minRowInk = math.max(2, (image.width * 0.004).round());
      final left = colCounts.indexWhere((count) => count >= minColumnInk);
      final right = colCounts.lastIndexWhere((count) => count >= minColumnInk);
      final top = rowCounts.indexWhere((count) => count >= minRowInk);
      final bottom = rowCounts.lastIndexWhere((count) => count >= minRowInk);
      if (left < 0 || right <= left || top < 0 || bottom <= top) return null;

      final scaleX = image.width / page.width;
      final scaleY = image.height / page.height;
      final rect = PdfRect(
        left / scaleX,
        page.height - top / scaleY,
        (right + 1) / scaleX,
        page.height - (bottom + 1) / scaleY,
      );
      if (rect.width < page.width * 0.18 || rect.height < page.height * 0.05) {
        return null;
      }

      final inkCoverage = inkPixels / (image.width * image.height);
      final widthRatio = rect.width / page.width;
      final heightRatio = rect.height / page.height;
      final looksLikeGraphicPage =
          inkCoverage > 0.22 ||
          (widthRatio > 0.92 && heightRatio > 0.78 && inkCoverage > 0.14);
      if (looksLikeGraphicPage) {
        _fitPageFallbackPages.add(page.pageNumber);
        return null;
      }

      return _inflatePdfRectClamped(
        rect,
        page,
        horizontal: page.width * 0.035,
        vertical: page.height * 0.025,
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  PdfRect _inflatePdfRectClamped(
    PdfRect rect,
    PdfPage page, {
    required double horizontal,
    required double vertical,
  }) {
    return PdfRect(
      math.max(0, rect.left - horizontal),
      math.min(page.height, rect.top + vertical),
      math.min(page.width, rect.right + horizontal),
      math.max(0, rect.bottom - vertical),
    );
  }

  void _goToPage(int page) {
    if (!_controller.isReady) return;
    final targetPage = (_totalPages > 0 ? page.clamp(1, _totalPages) : page)
        .toInt();
    unawaited(_goToPageWithView(targetPage));
  }

  Future<void> _goToPageWithView(int page) async {
    await _controller.goToPage(pageNumber: page);
    if (!mounted) return;
    setState(() => _currentPage = page);
    _scheduleApplyViewMode();
  }

  Future<void> _restorePendingInitialPage(
    PdfDocument document,
    PdfViewerController controller,
  ) async {
    final pendingPage = _pendingInitialPage;
    if (pendingPage == null || !controller.isReady) return;

    _pendingInitialPage = null;
    final targetPage = pendingPage.clamp(1, document.pages.length).toInt();
    await controller.goToPage(pageNumber: targetPage, duration: Duration.zero);
    if (!mounted) return;
    setState(() => _currentPage = targetPage);
  }

  void _showViewSheet(BuildContext context) {
    final content = _PdfViewSheet(
      viewMode: _viewMode,
      onViewModeSelected: _setViewMode,
      readerTheme: _readerTheme,
      onThemeSelected: _setReaderTheme,
    );

    if (_isNativeDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: content),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => content,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    if (key == LogicalKeyboardKey.escape) {
      if (_zenMode) {
        _setZenMode(false);
      } else {
        _closeReader();
      }
      return;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      _setZenMode(!_zenMode);
      return;
    }
    if (isMeta && key == LogicalKeyboardKey.keyB) {
      _addBookmark();
      return;
    }
    if (isMeta && key == LogicalKeyboardKey.digit0) {
      _setViewMode(_PdfViewMode.fitWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDesktop = _usesDesktopChrome;
    final displayTitle = bookTitleLabel(context, _pdfDisplayTitle(widget.book));
    final bgColor = _readerTheme.backgroundColor;
    final fgColor = _readerTheme.textColor;
    final viewerColor = _readerTheme == ReaderTheme.dark
        ? MokuColors.nightBase
        : _readerTheme.backgroundColor;
    final showOverlayControls = _showControls && (!isDesktop || _zenMode);

    final pdfViewer = PdfViewer.file(
      widget.book.filePath,
      key: ValueKey(
        'pdf-reader-${widget.book.id}-$isDesktop-$_viewerRebuildEpoch',
      ),
      controller: _controller,
      initialPageNumber: _pendingInitialPage ?? _currentPage,
      params: PdfViewerParams(
        backgroundColor: viewerColor,
        margin: isDesktop ? 0 : 6,
        pageDropShadow: null,
        enableTextSelection: true,
        calculateInitialZoom: (document, controller, fitWholePage, fitWidth) {
          return switch (_viewMode) {
            _PdfViewMode.fitPage => fitWholePage,
            _PdfViewMode.actualSize => 1.0,
            _ => isDesktop ? fitWidth : fitWholePage,
          };
        },
        onPageChanged: (pageNumber) {
          if (!mounted) return;
          setState(() => _currentPage = pageNumber ?? 1);
          _saveProgress();
        },
        onViewerReady: (document, controller) {
          if (!mounted) return;
          final visiblePage = controller.isReady ? controller.pageNumber : null;
          setState(() {
            _totalPages = document.pages.length;
            _currentPage = _pendingInitialPage ?? visiblePage ?? _currentPage;
          });
          unawaited(
            _restorePendingInitialPage(document, controller).whenComplete(
              () => _scheduleApplyViewMode(duration: Duration.zero),
            ),
          );
        },
      ),
    );

    final readerStack = Stack(
      children: [
        Positioned.fill(child: pdfViewer),

        // Tap area to toggle overlay controls in mobile and zen mode.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _showControls = !_showControls),
            child: const SizedBox.shrink(),
          ),
        ),

        if (showOverlayControls)
          _PdfOverlayTopBar(
            title: displayTitle,
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            topInset: MediaQuery.of(context).padding.top,
            onBack: _closeReader,
            onSettings: () => _showViewSheet(context),
          ),

        if (showOverlayControls && _totalPages > 0)
          _PdfBottomControls(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageChanged: _goToPage,
          ),

        if (_zenMode)
          Positioned(
            top: 14,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.75),
                borderRadius: MokuRadius.smAll,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  'Exit Zen  Esc / Z',
                  style: MokuText.caption(
                    color: fgColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final readerContent = isDesktop && _sidebarVisible && !_zenMode
        ? Row(
            children: [
              SizedBox(
                width: 260,
                child: _PdfSidePanel(
                  backgroundColor: bgColor,
                  foregroundColor: fgColor,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  bookmarks: _bookmarks,
                  onPageSelected: _goToPage,
                ),
              ),
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: fgColor.withValues(alpha: 0.12),
              ),
              Expanded(child: readerStack),
            ],
          )
        : readerStack;

    final body = isDesktop && !_zenMode
        ? Column(
            children: [
              _PdfDesktopToolbar(
                titleBarHeight: _titleBarHeight,
                title: displayTitle,
                subtitle: _totalPages > 0
                    ? l10n.readerPageOf(
                        currentPage: _currentPage,
                        totalPages: _totalPages,
                      )
                    : 'PDF',
                progressLabel: _totalPages > 0
                    ? '$_currentPage / $_totalPages'
                    : '',
                backgroundColor: bgColor,
                foregroundColor: fgColor,
                bookmarkConfirmed: _bookmarkConfirmed,
                sidebarVisible: _sidebarVisible,
                viewMode: _viewMode,
                onBack: _closeReader,
                onBookmark: _addBookmark,
                onViewOptions: () => _showViewSheet(context),
                onZenMode: () => _setZenMode(true),
                onToggleSidebar: () =>
                    setState(() => _sidebarVisible = !_sidebarVisible),
              ),
              Expanded(child: readerContent),
              if (_totalPages > 0)
                _PdfDesktopProgressBar(
                  backgroundColor: bgColor,
                  foregroundColor: fgColor,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  onPageChanged: _goToPage,
                ),
            ],
          )
        : readerStack;

    final scaffold = Scaffold(backgroundColor: bgColor, body: body);

    if (_isNativeDesktop) {
      return KeyboardListener(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

String _pdfDisplayTitle(Book book) {
  final rawTitle = book.title.trim().isNotEmpty
      ? book.title.trim()
      : _filenameStem(book.filePath);
  final withoutExtension = rawTitle.replaceFirst(
    RegExp(r'\.pdf$', caseSensitive: false),
    '',
  );

  final slugLike =
      withoutExtension.contains(RegExp('[-_]')) &&
      !withoutExtension.contains(RegExp(r'\s')) &&
      RegExp(
        r'^[a-z0-9][a-z0-9_-]*$',
        caseSensitive: false,
      ).hasMatch(withoutExtension);

  if (!slugLike) return withoutExtension;

  final withoutImportSuffix = withoutExtension.replaceFirst(
    RegExp(r'[-_][0-9a-f]{8,}$', caseSensitive: false),
    '',
  );
  final words = withoutImportSuffix
      .split(RegExp('[-_]+'))
      .where((word) => word.trim().isNotEmpty)
      .toList();
  if (words.isEmpty) return withoutExtension;

  const smallWords = {
    'a',
    'an',
    'and',
    'as',
    'at',
    'but',
    'by',
    'for',
    'from',
    'in',
    'of',
    'on',
    'or',
    'the',
    'to',
    'with',
  };

  return words.indexed
      .map((entry) {
        final index = entry.$1;
        final word = entry.$2.toLowerCase();
        if (index > 0 && smallWords.contains(word)) return word;
        return word[0].toUpperCase() + word.substring(1);
      })
      .join(' ');
}

String _filenameStem(String path) {
  final normalized = path.replaceAll('\\', '/');
  final filename = normalized.split('/').last;
  final dot = filename.lastIndexOf('.');
  return dot > 0 ? filename.substring(0, dot) : filename;
}

enum _PdfViewMode { fitContent, fitWidth, fitPage, actualSize }

extension _PdfViewModeDetails on _PdfViewMode {
  String get label {
    return switch (this) {
      _PdfViewMode.fitContent => 'Fit Content',
      _PdfViewMode.fitWidth => 'Fit Width',
      _PdfViewMode.fitPage => 'Fit Page',
      _PdfViewMode.actualSize => 'Actual Size',
    };
  }

  IconData get icon {
    return switch (this) {
      _PdfViewMode.fitContent => Icons.crop_rounded,
      _PdfViewMode.fitWidth => Icons.fit_screen_rounded,
      _PdfViewMode.fitPage => Icons.fullscreen_rounded,
      _PdfViewMode.actualSize => Icons.filter_center_focus_rounded,
    };
  }
}

class _PdfDesktopToolbar extends StatelessWidget {
  final double titleBarHeight;
  final String title;
  final String subtitle;
  final String progressLabel;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool bookmarkConfirmed;
  final bool sidebarVisible;
  final _PdfViewMode viewMode;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onViewOptions;
  final VoidCallback onZenMode;
  final VoidCallback onToggleSidebar;

  const _PdfDesktopToolbar({
    required this.titleBarHeight,
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.bookmarkConfirmed,
    required this.sidebarVisible,
    required this.viewMode,
    required this.onBack,
    required this.onBookmark,
    required this.onViewOptions,
    required this.onZenMode,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final dim = foregroundColor.withValues(alpha: 0.45);
    final dividerColor = foregroundColor.withValues(alpha: 0.12);
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: titleBarHeight),
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: foregroundColor,
                      size: 18,
                    ),
                    onPressed: onBack,
                    tooltip: 'Close Reader  Esc',
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MokuText.serifNum(
                            MokuTypeSize.small,
                            color: foregroundColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: dim,
                            fontSize: MokuTypeSize.tiny,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (progressLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        progressLabel,
                        style: TextStyle(color: dim, fontSize: 11),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      bookmarkConfirmed
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: bookmarkConfirmed
                          ? colorScheme.primary
                          : foregroundColor,
                      size: 18,
                    ),
                    onPressed: onBookmark,
                    tooltip: 'Bookmark  Cmd+B',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(viewMode.icon, color: foregroundColor, size: 18),
                    onPressed: onViewOptions,
                    tooltip: 'PDF View',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.crop_free_rounded,
                      color: foregroundColor,
                      size: 18,
                    ),
                    onPressed: onZenMode,
                    tooltip: 'Zen Mode  Z',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_list_bulleted_rounded,
                      color: sidebarVisible
                          ? colorScheme.primary
                          : foregroundColor,
                      size: 18,
                    ),
                    onPressed: onToggleSidebar,
                    tooltip: sidebarVisible ? 'Hide sidebar' : 'Show sidebar',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }
}

class _PdfDesktopProgressBar extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PdfDesktopProgressBar({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: SizedBox(
        height: 18,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 5),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: foregroundColor.withValues(alpha: 0.12),
              thumbColor: Theme.of(context).colorScheme.primary,
            ),
            child: Slider(
              value: currentPage.toDouble(),
              min: 1,
              max: totalPages.toDouble(),
              onChanged: (value) => onPageChanged(value.round()),
            ),
          ),
        ),
      ),
    );
  }
}

class _PdfSidePanel extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final int currentPage;
  final int totalPages;
  final List<db.Bookmark> bookmarks;
  final ValueChanged<int> onPageSelected;

  const _PdfSidePanel({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.currentPage,
    required this.totalPages,
    required this.bookmarks,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final dim = foregroundColor.withValues(alpha: 0.55);
    return ColoredBox(
      color: backgroundColor,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
              child: Text('PDF', style: MokuText.sectionLabel(color: dim)),
            ),
            TabBar(
              labelColor: foregroundColor,
              unselectedLabelColor: dim,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: [
                Tab(text: totalPages > 0 ? 'Pages $totalPages' : 'Pages'),
                Tab(text: 'Bookmarks ${bookmarks.length}'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  totalPages > 0
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: totalPages,
                          itemBuilder: (context, index) {
                            final page = index + 1;
                            return MokuPanelItem(
                              compact: true,
                              selected: currentPage == page,
                              leading: Icon(
                                Icons.description_outlined,
                                size: 15,
                                color: currentPage == page
                                    ? Theme.of(context).colorScheme.primary
                                    : dim,
                              ),
                              title: 'Page $page',
                              onTap: () => onPageSelected(page),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            'Loading pages...',
                            style: MokuText.caption(color: dim),
                          ),
                        ),
                  bookmarks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bookmark_border_rounded,
                                size: 32,
                                color: foregroundColor.withValues(alpha: 0.25),
                              ),
                              const SizedBox(height: MokuSpacing.s3),
                              Text(
                                'No bookmarks yet',
                                style: MokuText.caption(color: dim),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: bookmarks.length,
                          itemBuilder: (context, index) {
                            final bookmark = bookmarks[index];
                            final page = bookmark.chapterIndex + 1;
                            return MokuPanelItem(
                              compact: true,
                              selected: currentPage == page,
                              leading: Icon(
                                Icons.bookmark_rounded,
                                size: 15,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: bookmark.title,
                              subtitle: 'Page $page',
                              onTap: () => onPageSelected(page),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfViewSheet extends StatefulWidget {
  final _PdfViewMode viewMode;
  final ValueChanged<_PdfViewMode> onViewModeSelected;
  final ReaderTheme readerTheme;
  final ValueChanged<ReaderTheme> onThemeSelected;

  const _PdfViewSheet({
    required this.viewMode,
    required this.onViewModeSelected,
    required this.readerTheme,
    required this.onThemeSelected,
  });

  @override
  State<_PdfViewSheet> createState() => _PdfViewSheetState();
}

class _PdfViewSheetState extends State<_PdfViewSheet> {
  late _PdfViewMode _viewMode;
  late ReaderTheme _readerTheme;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
    _readerTheme = widget.readerTheme;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PDF View', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 18),
          Text(
            'Layout',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _PdfViewMode.values.map((mode) {
              final selected = mode == _viewMode;
              return ChoiceChip(
                selected: selected,
                avatar: Icon(
                  mode.icon,
                  size: 17,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                label: Text(mode.label),
                onSelected: (_) {
                  setState(() => _viewMode = mode);
                  widget.onViewModeSelected(mode);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Text(
            'Surface',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ReaderTheme.values.map((theme) {
              final isActive = identical(theme, _readerTheme);
              return GestureDetector(
                onTap: () {
                  setState(() => _readerTheme = theme);
                  widget.onThemeSelected(theme);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? colorScheme.primary
                          : Colors.grey.withValues(alpha: 0.4),
                      width: isActive ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isActive ? Icons.check : Icons.text_fields,
                      color: theme.textColor,
                      size: isActive ? 20 : 18,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PdfOverlayTopBar extends StatelessWidget {
  final String title;
  final Color backgroundColor;
  final Color foregroundColor;
  final double topInset;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  const _PdfOverlayTopBar({
    required this.title,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.topInset,
    required this.onBack,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topInset),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundColor.withValues(alpha: 0.95),
              backgroundColor.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: foregroundColor),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  style: MokuText.body(
                    color: foregroundColor,
                    weight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: foregroundColor),
                tooltip: 'PDF View',
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfBottomControls extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PdfBottomControls({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Positioned(
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
              backgroundColor.withValues(alpha: 0.95),
              backgroundColor.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: foregroundColor.withValues(alpha: 0.2),
                  thumbColor: Theme.of(context).colorScheme.primary,
                ),
                child: Semantics(
                  label: l10n.readerPageOf(
                    currentPage: currentPage,
                    totalPages: totalPages,
                  ),
                  child: Slider(
                    value: currentPage.toDouble(),
                    min: 1,
                    max: totalPages.toDouble(),
                    onChanged: (value) => onPageChanged(value.round()),
                  ),
                ),
              ),
              Text(
                l10n.readerPageOf(
                  currentPage: currentPage,
                  totalPages: totalPages,
                ),
                style: MokuText.caption(
                  color: foregroundColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
