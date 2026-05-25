import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/database/database.dart'
    hide Book, Bookmark, Highlight, BookCollection;
import '../../../core/database/database.dart' as db_rec
    show Bookmark, Highlight;
import '../../../core/localization/bidi_text.dart';
import '../../../core/models/book.dart';
import '../../../core/models/book_localizations.dart';
import '../../../core/models/reader_content_profile.dart';
import '../../../core/services/book_service.dart';
import '../../../core/sync/auto_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../reader_accessibility.dart';
import '../reader_localizations.dart';
import '../cubit/reader_cubit.dart';
import '../cubit/reader_state.dart';
import 'annotations_screen.dart';
import 'pdf_reader_screen.dart';
import 'cbz_reader_screen.dart';

// ---------------------------------------------------------------------------
// 1. ReaderScreen — entry point, routes to format-specific reader
// ---------------------------------------------------------------------------

class ReaderScreen extends StatelessWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    // PDF and CBZ get their own dedicated reader screens
    if (book.format == BookFormat.pdf) {
      return PdfReaderScreen(book: book);
    }
    if (book.format == BookFormat.cbz) {
      return CbzReaderScreen(book: book);
    }

    // EPUB, TXT, HTML all use the WebView-based reader
    return BlocProvider(
      create: (context) => ReaderCubit(
        database: context.read<AppDatabase>(),
        bookService: context.read<BookService>(),
        book: book,
        autoSync: context.read<AutoSyncService>(),
      )..loadBook(),
      child: const _ReaderView(),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. _ReaderView — stateful, owns WebViewController & zen‑mode hint animation
// ---------------------------------------------------------------------------

class _ReaderView extends StatefulWidget {
  const _ReaderView();

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<_ReaderView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late WebViewController _webController;
  bool _webViewReady = false;

  // Desktop-specific
  bool _sidebarVisible = false;
  bool _sidebarInitialized = false;
  late final FocusNode _keyboardFocus;
  // Seeded to 28pt on macOS so the first frame already clears traffic lights.
  double _titleBarHeight =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? 28.0 : 0.0;

  late ReaderCubit _cubit;

  // Selection state for highlight toolbar
  String? _selectedText;
  int? _selectionStartOffset;
  int? _selectionEndOffset;

  // Zen exit overlay
  bool _zenExitOverlayVisible = false;
  bool _bookmarkToastVisible = false;

  // Track last loaded state to avoid redundant reloads
  String _lastLoadedContent = '';
  String _lastAccessibilityPreviewSource = '';
  String _lastAccessibilityPreview = '';
  double _lastLoadedFontSize = 0;
  double _lastLoadedLineHeight = 0;
  double _lastLoadedMargin = 0;
  ReaderFontFamily? _lastLoadedFontFamily;
  ReaderTheme? _lastLoadedTheme;
  ReaderDirectionOverride? _lastLoadedDirectionOverride;
  ReaderContentProfile? _lastLoadedContentProfile;

  // Pagination start position: 'restore', 'first', 'last', 'fraction:X', 'fragment:id'
  String _pendingStartPosition = 'restore';

  // Zen‑mode exit overlay animation
  late AnimationController _zenHintController;
  late Animation<double> _zenHintOpacity;
  Timer? _zenHintTimer;
  Timer? _bookmarkToastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keyboardFocus = FocusNode();
    _syncTitleBarHeight();
    // Open the sidebar by default on desktop after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_sidebarInitialized) {
        final nativeDesktop = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.windows);
        if (nativeDesktop) setState(() => _sidebarVisible = true);
        _sidebarInitialized = true;
      }
    });

    // Zen hint fade controller (1 s fade‑out)
    _zenHintController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _zenHintOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _zenHintController, curve: Curves.easeOut),
    );

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MokuBridge', onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _webViewReady = true);
            final cubit = context.read<ReaderCubit>();
            final state = cubit.state;
            _applyHighlightsToWebView(state.highlights);

            // If there's a pending highlight to navigate to, do it after load
            if (state.pendingHighlightText != null) {
              final escaped = state.pendingHighlightText!
                  .replaceAll('\\', '\\\\')
                  .replaceAll("'", "\\'")
                  .replaceAll('\n', '\\n');
              // Small delay to let highlights render first
              Future.delayed(const Duration(milliseconds: 200), () {
                _webController.runJavaScript(
                  "scrollToHighlightText('$escaped');",
                );
                cubit.clearPendingHighlight();
              });
            }
          },
        ),
      );

    // setBackgroundColor calls setOpaque internally, which is not implemented
    // on macOS in webview_flutter_wkwebview — skip it there.
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      _webController.setBackgroundColor(Colors.transparent);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<ReaderCubit>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _cubit.finalizeSession();
    } else if (state == AppLifecycleState.resumed) {
      _cubit.restartSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zenHintTimer?.cancel();
    _bookmarkToastTimer?.cancel();
    _zenHintController.dispose();
    _keyboardFocus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cubit.finalizeSession();
    super.dispose();
  }

  // -- Zen exit overlay helpers -----------------------------------------------

  void _showZenExitOverlay() {
    _zenHintTimer?.cancel();
    _zenHintController.reset();
    setState(() {
      _zenExitOverlayVisible = true;
    });
    _zenHintTimer = Timer(const Duration(seconds: 3), () {
      _zenHintController.forward().then((_) {
        if (mounted) {
          setState(() {
            _zenExitOverlayVisible = false;
          });
        }
      });
    });
  }

  void _showBookmarkToast() {
    _bookmarkToastTimer?.cancel();
    setState(() {
      _bookmarkToastVisible = true;
    });
    _bookmarkToastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _bookmarkToastVisible = false;
        });
      }
    });
  }

  String _readerAccessibilityPreview(String content) {
    if (content == _lastAccessibilityPreviewSource) {
      return _lastAccessibilityPreview;
    }

    _lastAccessibilityPreviewSource = content;
    _lastAccessibilityPreview = readerAccessibilityTextPreview(content);
    return _lastAccessibilityPreview;
  }

  void _activateReaderSurface(ReaderState state) {
    final cubit = context.read<ReaderCubit>();
    if (state.zenMode) {
      _zenHintTimer?.cancel();
      setState(() {
        _zenExitOverlayVisible = false;
      });
      cubit.toggleZenMode();
      return;
    }

    cubit.toggleControls();
  }

  Widget _buildReaderAccessibilitySurface(
    BuildContext context,
    ReaderState state,
  ) {
    final l10n = context.l10n;
    final bookTitle = bidiWrappedText(
      context,
      bookTitleLabel(context, state.book.title),
    );
    final chapterTitle = bidiWrappedText(
      context,
      readerChapterTitle(context, state, state.currentChapter),
    );
    final preview = bidiWrappedText(
      context,
      _readerAccessibilityPreview(state.currentContent),
    );
    final totalChapters = state.chapters.length;
    final overallProgress = totalChapters == 0
        ? 0.0
        : ((state.currentChapter + state.scrollProgress) / totalChapters).clamp(
            0.0,
            1.0,
          );
    final label = [
      bookTitle,
      chapterTitle,
      '${l10n.readerReadingDirection}: ${readerContentDirectionLabel(context, state)}',
    ].join('. ');
    final valueParts = <String>[
      if (state.totalPages > 1)
        l10n.readerPageOf(
          currentPage: state.currentPage + 1,
          totalPages: state.totalPages,
        ),
      if (totalChapters > 0)
        l10n.readerChapterProgress(
          chapterTitle: chapterTitle,
          percent: (overallProgress * 100).round(),
        ),
      if (preview.isNotEmpty) preview,
    ];

    return Positioned.fill(
      child: Semantics(
        container: true,
        focusable: true,
        readOnly: true,
        multiline: true,
        label: label,
        value: valueParts.join('. '),
        onTap: () => _activateReaderSurface(state),
        child: const SizedBox.expand(),
      ),
    );
  }

  // -- JS bridge -----------------------------------------------------------

  void _onJsMessage(JavaScriptMessage message) {
    final data = message.message;

    if (data.startsWith('page:')) {
      // page:currentPage:totalPages
      final parts = data.split(':');
      if (parts.length == 3) {
        final page = int.tryParse(parts[1]) ?? 0;
        final total = int.tryParse(parts[2]) ?? 1;
        context.read<ReaderCubit>().updatePageInfo(page, total);
      }
    } else if (data == 'chapter:next') {
      final cubit = context.read<ReaderCubit>();
      if (cubit.state.hasNextChapter) {
        _pendingStartPosition = 'first';
        cubit.nextChapter();
      }
    } else if (data == 'chapter:prev') {
      final cubit = context.read<ReaderCubit>();
      if (cubit.state.hasPreviousChapter) {
        _pendingStartPosition = 'last';
        cubit.previousChapter();
      }
    } else if (data == 'tap') {
      final cubit = context.read<ReaderCubit>();
      if (cubit.state.zenMode) {
        // Show floating exit overlay instead of instant exit
        _showZenExitOverlay();
      } else {
        cubit.toggleControls();
      }
    } else if (data == 'doubletap') {
      final cubit = context.read<ReaderCubit>();
      if (cubit.state.zenMode) {
        cubit.toggleZenMode();
      }
    } else if (data.startsWith('selection:')) {
      final jsonStr = data.substring(10);
      try {
        final selData = json.decode(jsonStr);
        final text = selData['text'] as String?;
        if (text != null && text.isNotEmpty) {
          setState(() {
            _selectedText = text;
            _selectionStartOffset = selData['startOffset'] as int?;
            _selectionEndOffset = selData['endOffset'] as int?;
          });
        }
      } catch (_) {}
    } else if (data == 'selection:cleared') {
      setState(() {
        _selectedText = null;
        _selectionStartOffset = null;
        _selectionEndOffset = null;
      });
    }
  }

  void _applyHighlightsToWebView(List highlights) {
    if (highlights.isEmpty) {
      _webController.runJavaScript(
        'if(typeof clearHighlights==="function") clearHighlights();',
      );
      return;
    }
    final highlightData = highlights
        .map((h) => {'text': h.selectedText, 'id': h.id, 'color': h.color})
        .toList();
    final jsonStr = json.encode(highlightData);
    final escaped = jsonStr.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    _webController.runJavaScript(
      "if(typeof applyHighlights==='function') applyHighlights('$escaped');",
    );
  }

  void _clearSelection() {
    _webController.runJavaScript('window.getSelection().removeAllRanges();');
    setState(() {
      _selectedText = null;
      _selectionStartOffset = null;
      _selectionEndOffset = null;
    });
  }

  // -- Highlight actions ---------------------------------------------------

  void _showHighlightActions(BuildContext context) {
    final text = _selectedText;
    final startOffset = _selectionStartOffset ?? 0;
    final endOffset = _selectionEndOffset ?? 0;
    final l10n = context.l10n;
    if (text == null || text.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  readerQuotedSelection(context, text),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.highlight),
                title: Text(l10n.readerHighlight),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ReaderCubit>().addHighlight(
                    text,
                    startOffset,
                    endOffset,
                  );
                  _clearSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add),
                title: Text(l10n.readerHighlightWithNote),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddNoteDialog(context, text, startOffset, endOffset);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.commonCopy),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  _clearSelection();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.readerCopiedToClipboard),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddNoteDialog(
    BuildContext context,
    String text,
    int startOffset,
    int endOffset,
  ) {
    final noteController = TextEditingController();
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.readerAddNote),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              readerQuotedSelection(context, text),
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
              final cubit = context.read<ReaderCubit>();
              await cubit.addHighlight(text, startOffset, endOffset);
              if (noteController.text.isNotEmpty) {
                final highlights = cubit.state.highlights;
                if (highlights.isNotEmpty) {
                  final lastHighlight = highlights.last;
                  await cubit.updateHighlightNote(
                    lastHighlight.id,
                    noteController.text,
                  );
                }
              }
              _clearSelection();
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  // -- HTML content --------------------------------------------------------

  void _loadContent(ReaderState state, {String startPosition = 'first'}) {
    setState(() => _webViewReady = false);
    final html = _wrapHtml(
      state.currentContent,
      state,
      startPosition: startPosition,
    );
    _webController.loadHtmlString(html);
  }

  String _wrapHtml(
    String content,
    ReaderState state, {
    String startPosition = 'first',
  }) {
    final bgColor = _colorToHex(state.readerTheme.backgroundColor);
    final textColor = _colorToHex(state.readerTheme.textColor);
    final fontFamily = state.fontFamily.cssFontFamilyFor(
      state.contentProfile.textDirection,
    );
    final fontSize = state.fontSize;
    final lineHeight = state.lineHeight;
    final hMargin = state.horizontalMargin.toInt();
    final colWidth = 'calc(100vw - ${2 * hMargin}px)';
    final colGap = '${2 * hMargin}px';
    final contentDirection = state.isContentRtl ? 'rtl' : 'ltr';
    final pageProgressionDirection = state.contentProfile.isPageProgressionRtl
        ? 'rtl'
        : 'ltr';
    final languageTag = state.contentLanguageTag;

    // Build start position JS object
    String startPosJs;
    if (startPosition == 'last') {
      startPosJs = "{ type: 'last' }";
    } else if (startPosition.startsWith('fraction:')) {
      startPosJs = "{ type: 'fraction', value: ${startPosition.substring(9)} }";
    } else if (startPosition.startsWith('fragment:')) {
      startPosJs =
          "{ type: 'fragment', value: '${startPosition.substring(9)}' }";
    } else {
      startPosJs = "{ type: 'first' }";
    }

    return '''
<!DOCTYPE html>
<html${languageTag == null ? '' : ' lang="$languageTag"'} dir="$contentDirection">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body {
    margin: 0;
    padding: 0;
    width: 100vw;
    height: 100vh;
    overflow: hidden;
    background-color: $bgColor;
    color: $textColor;
  }
  #moku-viewport {
    width: 100vw;
    height: 100vh;
    overflow: hidden;
    position: relative;
  }
  #moku-content {
    height: calc(100vh - 72px);
    margin: 24px ${hMargin}px 48px ${hMargin}px;
    padding: 0;
    column-width: $colWidth;
    column-gap: $colGap;
    column-fill: auto;
    font-family: $fontFamily;
    font-size: ${fontSize}px;
    line-height: $lineHeight;
    word-wrap: break-word;
    overflow-wrap: break-word;
    -webkit-text-size-adjust: none;
    transition: transform 0.25s ease-out;
  }
  #moku-chapter {
    direction: $contentDirection;
    text-align: start;
  }
  h1, h2, h3, h4, h5, h6 {
    margin: 1em 0 0.5em 0;
    line-height: 1.3;
    break-inside: avoid;
    page-break-inside: avoid;
  }
  h1 { font-size: 1.6em; }
  h2 { font-size: 1.4em; }
  h3 { font-size: 1.2em; }
  p { margin: 0.8em 0; text-align: justify; }
  img {
    max-width: 100%;
    max-height: 80vh;
    height: auto;
    display: block;
    margin: 1em auto;
    break-inside: avoid;
    page-break-inside: avoid;
  }
  figure {
    break-inside: avoid;
    page-break-inside: avoid;
    margin: 1em 0;
  }
  a { color: inherit; text-decoration: underline; }
  blockquote {
    border-inline-start: 3px solid $textColor;
    opacity: 0.8;
    padding-inline-start: 16px;
    margin: 1em 0;
    break-inside: avoid;
    page-break-inside: avoid;
  }
  pre, code {
    font-family: monospace;
    font-size: 0.9em;
    background: rgba(128,128,128,0.1);
    padding: 2px 4px;
    border-radius: 3px;
  }
  pre {
    padding: 12px;
    overflow-x: auto;
    break-inside: avoid;
    page-break-inside: avoid;
  }
  table {
    border-collapse: collapse;
    width: 100%;
    margin: 1em 0;
    break-inside: avoid;
    page-break-inside: avoid;
  }
  td, th { border: 1px solid rgba(128,128,128,0.3); padding: 8px; }
  .moku-highlight {
    background-color: rgba(255, 235, 59, 0.4);
    border-radius: 2px;
    cursor: pointer;
  }
</style>
</head>
<body>
<div id="moku-viewport">
  <div id="moku-content">
    <div id="moku-chapter">
$content
    </div>
  </div>
</div>
<script>
// --- Start position ---
window._mokuStartPosition = $startPosJs;
window._mokuPageDirection = '$pageProgressionDirection';

// --- Pagination Engine ---
var mokuPagination = {
  currentPage: 0,
  totalPages: 1,

  init: function() {
    var content = document.getElementById('moku-content');
    if (!content) return;
    var pageWidth = window.innerWidth;
    this.totalPages = Math.max(1, Math.ceil(content.scrollWidth / pageWidth));

    var start = window._mokuStartPosition || { type: 'first' };
    if (start.type === 'last') {
      this.goToPage(this.totalPages - 1, true);
    } else if (start.type === 'fraction' && start.value > 0) {
      var page = Math.round(start.value * Math.max(this.totalPages - 1, 0));
      this.goToPage(page, true);
    } else if (start.type === 'fragment' && start.value) {
      this.goToFragment(start.value);
    } else {
      this.goToPage(0, true);
    }
  },

  goToPage: function(page, skipAnimation) {
    page = Math.max(0, Math.min(page, this.totalPages - 1));
    this.currentPage = page;
    var content = document.getElementById('moku-content');
    if (skipAnimation) {
      content.style.transition = 'none';
      content.offsetHeight;
    }
    content.style.transform = 'translateX(' + (-page * window.innerWidth) + 'px)';
    if (skipAnimation) {
      content.offsetHeight;
      content.style.transition = 'transform 0.25s ease-out';
    }
    this.reportPage();
  },

  nextPage: function() {
    if (this.currentPage >= this.totalPages - 1) {
      MokuBridge.postMessage('chapter:next');
      return;
    }
    this.goToPage(this.currentPage + 1);
  },

  prevPage: function() {
    if (this.currentPage <= 0) {
      MokuBridge.postMessage('chapter:prev');
      return;
    }
    this.goToPage(this.currentPage - 1);
  },

  reportPage: function() {
    MokuBridge.postMessage('page:' + this.currentPage + ':' + this.totalPages);
  },

  goToFragment: function(fragmentId) {
    var el = document.getElementById(fragmentId);
    if (!el) { this.goToPage(0, true); return; }
    var rect = el.getBoundingClientRect();
    var page = Math.floor((rect.left + this.currentPage * window.innerWidth) / window.innerWidth);
    this.goToPage(Math.max(0, page), true);
  }
};

// --- Tap & Gesture Handling ---
var _mokuLastTap = 0;
var _mokuTapTimer = null;
var _touchStartX = 0;
var _touchStartY = 0;
var _touchMoved = false;

document.addEventListener('touchstart', function(e) {
  _touchStartX = e.changedTouches[0].clientX;
  _touchStartY = e.changedTouches[0].clientY;
  _touchMoved = false;
}, { passive: true });

document.addEventListener('touchmove', function(e) {
  var dx = Math.abs(e.changedTouches[0].clientX - _touchStartX);
  var dy = Math.abs(e.changedTouches[0].clientY - _touchStartY);
  if (dx > 10 || dy > 10) _touchMoved = true;
}, { passive: true });

document.addEventListener('touchend', function(e) {
  if (!_touchMoved) return;
  var dx = e.changedTouches[0].clientX - _touchStartX;
  var dy = e.changedTouches[0].clientY - _touchStartY;
  if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) {
    if (window._mokuPageDirection === 'rtl') {
      if (dx < 0) mokuPagination.prevPage();
      else mokuPagination.nextPage();
    } else {
      if (dx < 0) mokuPagination.nextPage();
      else mokuPagination.prevPage();
    }
  }
}, { passive: true });

document.addEventListener('click', function(e) {
  if (e.target.tagName === 'A') return;
  if (_touchMoved) return;
  var sel = window.getSelection();
  if (sel && sel.toString().trim().length > 0) return;

  var x = e.clientX;
  var w = window.innerWidth;
  var now = Date.now();

  if (now - _mokuLastTap < 300) {
    clearTimeout(_mokuTapTimer);
    _mokuLastTap = 0;
    MokuBridge.postMessage('doubletap');
  } else {
    _mokuLastTap = now;
    var zone = x < w * 0.33 ? 'left' : (x > w * 0.67 ? 'right' : 'center');
    _mokuTapTimer = setTimeout(function() {
      if (_mokuLastTap > 0) {
        _mokuLastTap = 0;
        if (zone === 'center') {
          MokuBridge.postMessage('tap');
          return;
        }

        if (window._mokuPageDirection === 'rtl') {
          if (zone === 'left') mokuPagination.nextPage();
          else if (zone === 'right') mokuPagination.prevPage();
        } else {
          if (zone === 'left') mokuPagination.prevPage();
          else if (zone === 'right') mokuPagination.nextPage();
        }
      }
    }, 300);
  }
});

// --- Selection Listener ---
var _mokuSelectionTimeout = null;
document.addEventListener('selectionchange', function() {
  clearTimeout(_mokuSelectionTimeout);
  _mokuSelectionTimeout = setTimeout(function() {
    var sel = window.getSelection();
    if (sel && sel.rangeCount > 0 && sel.toString().trim().length > 0) {
      var range = sel.getRangeAt(0);
      var preRange = document.createRange();
      preRange.selectNodeContents(document.body);
      preRange.setEnd(range.startContainer, range.startOffset);
      var startOffset = preRange.toString().length;
      var endOffset = startOffset + sel.toString().length;
      var data = JSON.stringify({
        text: sel.toString().trim(),
        startOffset: startOffset,
        endOffset: endOffset
      });
      MokuBridge.postMessage('selection:' + data);
    } else {
      MokuBridge.postMessage('selection:cleared');
    }
  }, 300);
});

// --- Highlight Functions ---
function clearHighlights() {
  var spans = document.querySelectorAll('.moku-highlight');
  spans.forEach(function(span) {
    var parent = span.parentNode;
    while (span.firstChild) {
      parent.insertBefore(span.firstChild, span);
    }
    parent.removeChild(span);
    parent.normalize();
  });
}

function applyHighlights(jsonStr) {
  clearHighlights();
  try {
    var highlights = JSON.parse(jsonStr);
    highlights.forEach(function(h) {
      highlightTextInBody(h.text, h.id, h.color);
    });
  } catch(e) {}
}

function highlightTextInBody(text, id, color) {
  if (!text || text.length === 0) return;
  var content = document.getElementById('moku-content');
  if (!content) return;

  // Collect all text nodes and build a combined string
  var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null, false);
  var textNodes = [];
  var allText = '';
  while (walker.nextNode()) {
    textNodes.push({ node: walker.currentNode, start: allText.length });
    allText += walker.currentNode.textContent;
  }

  var idx = allText.indexOf(text);
  if (idx === -1) return;
  var targetEnd = idx + text.length;

  // Determine background color
  var bgColor = 'rgba(255, 235, 59, 0.4)';
  if (color) {
    var r = parseInt(color.substr(1,2), 16);
    var g = parseInt(color.substr(3,2), 16);
    var b = parseInt(color.substr(5,2), 16);
    bgColor = 'rgba(' + r + ',' + g + ',' + b + ',0.4)';
  }

  // Find affected text nodes and wrap each segment individually
  // (handles cross-element ranges that surroundContents can't)
  var segments = [];
  for (var i = 0; i < textNodes.length; i++) {
    var tn = textNodes[i];
    var nodeEnd = tn.start + tn.node.textContent.length;
    if (nodeEnd <= idx) continue;
    if (tn.start >= targetEnd) break;
    segments.push({
      node: tn.node,
      start: Math.max(0, idx - tn.start),
      end: Math.min(tn.node.textContent.length, targetEnd - tn.start)
    });
  }

  // Process in reverse to avoid offset invalidation
  for (var j = segments.length - 1; j >= 0; j--) {
    var seg = segments[j];
    try {
      var range = document.createRange();
      range.setStart(seg.node, seg.start);
      range.setEnd(seg.node, seg.end);
      var span = document.createElement('span');
      span.className = 'moku-highlight';
      span.dataset.highlightId = id || '';
      span.style.backgroundColor = bgColor;
      range.surroundContents(span);
    } catch(e) {}
  }
}

// --- Scroll to a specific highlight text and show it ---
function scrollToHighlightText(text) {
  if (!text || text.length === 0) return;
  var content = document.getElementById('moku-content');
  if (!content) return;

  // First check if there's already a highlight span with this text
  var spans = content.querySelectorAll('.moku-highlight');
  for (var i = 0; i < spans.length; i++) {
    if (spans[i].textContent.indexOf(text) !== -1 ||
        text.indexOf(spans[i].textContent) !== -1) {
      var rect = spans[i].getBoundingClientRect();
      var page = Math.floor(
        (rect.left + mokuPagination.currentPage * window.innerWidth) /
          window.innerWidth
      );
      mokuPagination.goToPage(Math.max(0, page));
      return;
    }
  }

  // Fallback: find the text in DOM and calculate its page
  var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null, false);
  var allText = '';
  var nodes = [];
  while (walker.nextNode()) {
    nodes.push({ node: walker.currentNode, start: allText.length });
    allText += walker.currentNode.textContent;
  }
  var idx = allText.indexOf(text);
  if (idx === -1) return;

  // Find the text node containing the start of the match
  for (var j = 0; j < nodes.length; j++) {
    var n = nodes[j];
    var nodeEnd = n.start + n.node.textContent.length;
    if (nodeEnd > idx) {
      var range = document.createRange();
      range.setStart(n.node, idx - n.start);
      range.setEnd(n.node, Math.min(n.node.textContent.length, idx - n.start + text.length));
      var rect = range.getBoundingClientRect();
      var page = Math.floor(
        (rect.left + mokuPagination.currentPage * window.innerWidth) /
          window.innerWidth
      );
      mokuPagination.goToPage(Math.max(0, page));
      return;
    }
  }
}

// --- Initialize ---
window.addEventListener('load', function() {
  setTimeout(function() {
    mokuPagination.init();
  }, 100);
});
</script>
</body>
</html>
''';
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  // -- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderCubit, ReaderState>(
      listenWhen: (prev, curr) =>
          prev.currentContent != curr.currentContent ||
          prev.readerTheme != curr.readerTheme ||
          prev.fontSize != curr.fontSize ||
          prev.lineHeight != curr.lineHeight ||
          prev.horizontalMargin != curr.horizontalMargin ||
          prev.fontFamily != curr.fontFamily ||
          prev.directionOverride != curr.directionOverride ||
          prev.contentProfile != curr.contentProfile ||
          prev.highlights != curr.highlights ||
          prev.zenMode != curr.zenMode ||
          prev.pendingHighlightText != curr.pendingHighlightText,
      listener: (context, state) {
        // Show zen exit overlay when entering zen mode
        if (state.zenMode && !_zenExitOverlayVisible) {
          _showZenExitOverlay();
        }

        final contentChanged = state.currentContent != _lastLoadedContent;
        final settingsChanged =
            state.fontSize != _lastLoadedFontSize ||
            state.lineHeight != _lastLoadedLineHeight ||
            state.horizontalMargin != _lastLoadedMargin ||
            state.fontFamily != _lastLoadedFontFamily ||
            state.readerTheme != _lastLoadedTheme ||
            state.directionOverride != _lastLoadedDirectionOverride ||
            state.contentProfile != _lastLoadedContentProfile;

        if (state.currentContent.isNotEmpty &&
            (contentChanged || settingsChanged)) {
          _lastLoadedContent = state.currentContent;
          _lastLoadedFontSize = state.fontSize;
          _lastLoadedLineHeight = state.lineHeight;
          _lastLoadedMargin = state.horizontalMargin;
          _lastLoadedFontFamily = state.fontFamily;
          _lastLoadedTheme = state.readerTheme;
          _lastLoadedDirectionOverride = state.directionOverride;
          _lastLoadedContentProfile = state.contentProfile;

          if (contentChanged) {
            // Chapter changed — use pending start position
            var sp = _pendingStartPosition;
            if (sp == 'restore') {
              sp = 'fraction:${state.scrollProgress}';
            }
            _pendingStartPosition = 'first';
            _loadContent(state, startPosition: sp);
          } else {
            // Settings changed — preserve current page position
            final fraction = state.totalPages > 1
                ? state.currentPage / (state.totalPages - 1)
                : 0.0;
            _loadContent(state, startPosition: 'fraction:$fraction');
          }
        } else if (_webViewReady) {
          _applyHighlightsToWebView(state.highlights);

          // Navigate to a pending highlight after highlights are applied
          if (state.pendingHighlightText != null) {
            final escaped = state.pendingHighlightText!
                .replaceAll('\\', '\\\\')
                .replaceAll("'", "\\'")
                .replaceAll('\n', '\\n');
            _webController.runJavaScript("scrollToHighlightText('$escaped');");
            context.read<ReaderCubit>().clearPendingHighlight();
          }
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;

        if (state.status == ReaderStatus.loading) {
          return Scaffold(
            backgroundColor: state.readerTheme.backgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == ReaderStatus.error) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.readerErrorTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.readerUnknownError,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (state.zenMode) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        final isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows);
        final readerStack = Stack(
          children: [
              // WebView reader — always respect top safe area to avoid notch
              SafeArea(
                top: true,
                bottom: !state.zenMode,
                child: WebViewWidget(controller: _webController),
              ),

              if (!state.showControls)
                _buildReaderAccessibilitySurface(context, state),

              // Top/bottom overlay controls — mobile only.
              // On desktop the persistent _DesktopReaderToolbar replaces these.
              if (state.showControls && !state.zenMode && !isDesktop)
                _TopControls(
                  title: bookTitleLabel(context, state.book.title),
                  chapterTitle: readerChapterTitle(
                    context,
                    state,
                    state.currentChapter,
                  ),
                  onZenMode: () => context.read<ReaderCubit>().toggleZenMode(),
                  onToggleSidebar: isDesktop
                      ? () => setState(() => _sidebarVisible = !_sidebarVisible)
                      : null,
                  sidebarVisible: _sidebarVisible,
                ),

              // Bottom controls
              if (state.showControls && !state.zenMode && !isDesktop)
                _BottomControls(
                  state: state,
                  bookmarkConfirmed: _bookmarkToastVisible,
                  onToc: () => context.read<ReaderCubit>().toggleToc(),
                  onSettings: () => _showSettingsSheet(context),
                  onBookmark: () async {
                    await context.read<ReaderCubit>().addBookmark(
                      readerChapterTitle(context, state, state.currentChapter),
                    );
                    if (!context.mounted) return;
                    _showBookmarkToast();
                  },
                  onAnnotations: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ReaderCubit>(),
                        child: AnnotationsScreen(book: state.book),
                      ),
                    ),
                  ),
                  onPageScrub: (page) {
                    _webController.runJavaScript(
                      'mokuPagination.goToPage($page);',
                    );
                  },
                  onBookScrub: (progress) {
                    final cubit = context.read<ReaderCubit>();
                    final totalCh = cubit.state.chapters.length;
                    if (totalCh == 0) return;
                    // Convert 0.0–1.0 progress to chapter + fraction
                    final scaled = progress * totalCh;
                    final chapter = scaled.floor().clamp(0, totalCh - 1);
                    final fraction = scaled - chapter;
                    if (chapter != cubit.state.currentChapter) {
                      _pendingStartPosition = 'fraction:$fraction';
                      cubit.goToChapter(chapter);
                    } else {
                      // Same chapter — just scrub within it
                      final page = (fraction * (cubit.state.totalPages - 1))
                          .round()
                          .clamp(0, cubit.state.totalPages - 1);
                      _webController.runJavaScript(
                        'mokuPagination.goToPage($page);',
                      );
                    }
                  },
                ),

              if (_bookmarkToastVisible && !state.zenMode)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 132,
                  child: SafeArea(
                    top: false,
                    child: Semantics(
                      liveRegion: true,
                      label: context.l10n.readerBookmarkAdded,
                      child: IgnorePointer(
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bookmark_added_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.readerBookmarkAdded,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Selection highlight FAB
              if (_selectedText != null &&
                  _selectedText!.isNotEmpty &&
                  !state.zenMode)
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'reader_highlight',
                    onPressed: () => _showHighlightActions(context),
                    icon: const Icon(Icons.highlight_rounded),
                    label: Text(l10n.readerHighlight),
                  ),
                ),

              // TOC drawer
              if (state.showToc && !state.zenMode)
                _TocDrawer(
                  chapters: state.chapters,
                  currentChapter: state.currentChapter,
                  onChapterTap: (index) {
                    final fragment = state.chapters[index].fragment;
                    _pendingStartPosition = fragment != null
                        ? 'fragment:$fragment'
                        : 'first';
                    context.read<ReaderCubit>().goToChapter(index);
                  },
                  onClose: () => context.read<ReaderCubit>().toggleToc(),
                ),

              // Progress bar — always visible, even in zen
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: state.zenMode ? 0.3 : 0.8,
                  duration: const Duration(milliseconds: 300),
                  child: LinearProgressIndicator(
                    value: state.chapters.isEmpty
                        ? 0
                        : (state.currentChapter + state.scrollProgress) /
                              state.chapters.length,
                    minHeight: state.zenMode ? 1.5 : 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),

              // Zen mode exit overlay — shows on center-tap, fades after 3s
              if (state.zenMode && _zenExitOverlayVisible)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FadeTransition(
                      opacity: _zenHintOpacity,
                      child: GestureDetector(
                        onTap: () {
                          _zenHintTimer?.cancel();
                          setState(() {
                            _zenExitOverlayVisible = false;
                          });
                          context.read<ReaderCubit>().toggleZenMode();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.readerExitZenMode,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );

        final readerContent = isDesktop && !state.zenMode
            ? Row(
                children: [
                  if (_sidebarVisible) ...[  
                    SizedBox(
                      width: 260,
                      child: _ReaderSidePanel(
                        book: state.book,
                        readerTheme: state.readerTheme,
                      ),
                    ),
                    VerticalDivider(
                      thickness: 1,
                      width: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ],
                  Expanded(child: readerStack),
                ],
              )
            : readerStack;

        final scaffold = Scaffold(
          backgroundColor: state.readerTheme.backgroundColor,
          body: isDesktop && !state.zenMode
              ? Column(
                  children: [
                    _DesktopReaderToolbar(
                      titleBarHeight: _titleBarHeight,
                      state: state,
                      sidebarVisible: _sidebarVisible,
                      bookmarkConfirmed: _bookmarkToastVisible,
                      onBack: () => Navigator.pop(context),
                      onToggleSidebar: () =>
                          setState(() => _sidebarVisible = !_sidebarVisible),
                      onBookmark: () => _addBookmarkFromKeyboard(),
                      onSettings: () => _showSettingsSheet(context),
                    ),
                    Expanded(child: readerContent),
                  ],
                )
              : readerContent,
        );

        // On desktop, wrap in a KeyboardListener for navigation shortcuts.
        if (isDesktop) {
          return KeyboardListener(
            focusNode: _keyboardFocus,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: scaffold,
          );
        }
        return scaffold;
      },
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows);
    final cubit = context.read<ReaderCubit>();

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: Dialog(
            child: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: BlocProvider.value(
                    value: cubit,
                    child: const _ReaderSettingsSheet(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _ReaderSettingsSheet(),
      ),
    );
  }

  Future<void> _syncTitleBarHeight() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    try {
      final h = await windowManager.getTitleBarHeight();
      if (mounted && h > 0 && h.toDouble() != _titleBarHeight) {
        setState(() => _titleBarHeight = h.toDouble());
      }
    } catch (_) {}
  }

  Future<void> _addBookmarkFromKeyboard() async {
    final cubit = _cubit;
    await cubit.addBookmark(
      readerChapterTitle(context, cubit.state, cubit.state.currentChapter),
    );
    if (!mounted) return;
    _showBookmarkToast();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final cubit = _cubit;
    final key = event.logicalKey;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final hasModifier = isMeta || isCtrl;

    if (key == LogicalKeyboardKey.escape) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      return;
    }

    // ⌘B / Ctrl+B  bookmark
    if (hasModifier && key == LogicalKeyboardKey.keyB) {
      _addBookmarkFromKeyboard();
      return;
    }

    // ⌘[ / Ctrl+[ or ⌘← / Ctrl+← : prev chapter
    final prevChapter =
        (hasModifier && key == LogicalKeyboardKey.bracketLeft) ||
        (hasModifier && key == LogicalKeyboardKey.arrowLeft);
    if (prevChapter) {
      if (cubit.state.hasPreviousChapter) cubit.previousChapter();
      return;
    }

    // ⌘] / Ctrl+] or ⌘→ / Ctrl+→ : next chapter
    final nextChapter =
        (hasModifier && key == LogicalKeyboardKey.bracketRight) ||
        (hasModifier && key == LogicalKeyboardKey.arrowRight);
    if (nextChapter) {
      if (cubit.state.hasNextChapter) cubit.nextChapter();
      return;
    }

    if (hasModifier) return; // don't intercept other Cmd shortcuts

    // ← : prev page
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      final prev = (cubit.state.currentPage - 1)
          .clamp(0, cubit.state.totalPages - 1);
      if (prev != cubit.state.currentPage) {
        _webController.runJavaScript('mokuPagination.goToPage($prev);');
      } else if (cubit.state.hasPreviousChapter) {
        _pendingStartPosition = 'last';
        cubit.previousChapter();
      }
      return;
    }

    // → / Space : next page
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.pageDown) {
      final next = (cubit.state.currentPage + 1)
          .clamp(0, cubit.state.totalPages - 1);
      if (next != cubit.state.currentPage) {
        _webController.runJavaScript('mokuPagination.goToPage($next);');
      } else if (cubit.state.hasNextChapter) {
        cubit.nextChapter();
      }
    }  // end next-page if
  }    // end _handleKeyEvent

} // end _ReaderViewState

// Parses a CSS hex colour string (#RRGGBB / #AARRGGBB) to a Flutter Color.
Color _parseHighlightColor(String hex) {
  final s = hex.replaceFirst('#', '');
  final value = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
  return Color(value ?? 0xFFFFEB3B);
}

// ---------------------------------------------------------------------------
// 3. _DesktopReaderToolbar
// ---------------------------------------------------------------------------

/// Persistent top bar shown on desktop (≥1000px) instead of the tap-to-show
/// overlay controls. Always visible, uses the active reader theme colours so
/// it blends with the reading surface.
class _DesktopReaderToolbar extends StatelessWidget {
  final double titleBarHeight;
  final ReaderState state;
  final bool sidebarVisible;
  final bool bookmarkConfirmed;
  final VoidCallback onBack;
  final VoidCallback onToggleSidebar;
  final VoidCallback onBookmark;
  final VoidCallback onSettings;

  const _DesktopReaderToolbar({
    required this.titleBarHeight,
    required this.state,
    required this.sidebarVisible,
    required this.bookmarkConfirmed,
    required this.onBack,
    required this.onToggleSidebar,
    required this.onBookmark,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final bg = state.readerTheme.backgroundColor;
    final fg = state.readerTheme.textColor;
    final dim = fg.withValues(alpha: 0.45);
    final dividerColor = fg.withValues(alpha: 0.12);
    final colorScheme = Theme.of(context).colorScheme;

    final chapterCount = state.chapters.length;
    final chapterLabel = chapterCount > 0
        ? '${state.currentChapter + 1} / $chapterCount'
        : '';

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Space above toolbar for the macOS title bar / traffic lights.
          SizedBox(height: titleBarHeight),

          // ── Toolbar row ──────────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  // Back
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: fg, size: 18),
                    onPressed: onBack,
                    tooltip: 'Close Reader  Esc',
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),

                  // Book + chapter title
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookTitleLabel(context, state.book.title),
                          style: GoogleFonts.literata(
                            color: fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          readerChapterTitle(
                              context, state, state.currentChapter),
                          style: TextStyle(
                            color: dim,
                            fontSize: 11,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Chapter progress
                  if (chapterLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        chapterLabel,
                        style: TextStyle(color: dim, fontSize: 11),
                      ),
                    ),

                  // Bookmark
                  IconButton(
                    icon: Icon(
                      bookmarkConfirmed
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: bookmarkConfirmed ? colorScheme.primary : fg,
                      size: 18,
                    ),
                    onPressed: onBookmark,
                    tooltip: 'Bookmark  ⌘B',
                    visualDensity: VisualDensity.compact,
                  ),

                  // Reading settings
                  IconButton(
                    icon: Icon(Icons.text_fields_rounded,
                        color: fg, size: 18),
                    onPressed: onSettings,
                    tooltip: 'Reading Settings',
                    visualDensity: VisualDensity.compact,
                  ),

                  // Sidebar toggle
                  IconButton(
                    icon: Icon(
                      Icons.format_list_bulleted_rounded,
                      color:
                          sidebarVisible ? colorScheme.primary : fg,
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

          // Subtle bottom divider
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. _ReaderSidePanel  (desktop only)
// ---------------------------------------------------------------------------

class _ReaderSidePanel extends StatefulWidget {
  final Book book;
  final ReaderTheme readerTheme;

  const _ReaderSidePanel({
    required this.book,
    required this.readerTheme,
  });

  @override
  State<_ReaderSidePanel> createState() => _ReaderSidePanelState();
}

class _ReaderSidePanelState extends State<_ReaderSidePanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<db_rec.Bookmark> _bookmarks = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final db = context.read<ReaderCubit>().database;
    final bm = await db.getBookmarksForBook(widget.book.id);
    if (mounted) setState(() { _bookmarks = bm; _loaded = true; });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReaderCubit>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final bg = Color.lerp(
      widget.readerTheme.backgroundColor,
      colorScheme.surface,
      0.08,
    )!;

    return Material(
      color: bg,
      child: Column(
        children: [
          // ── Tab bar ──────────────────────────────────────────────────────
          Container(
            color: bg,
            child: TabBar(
              controller: _tabs,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(icon: const Icon(Icons.list_rounded, size: 16), text: 'Contents'),
                Tab(icon: const Icon(Icons.bookmark_outline_rounded, size: 16), text: 'Bookmarks'),
                Tab(icon: const Icon(Icons.highlight_rounded, size: 16), text: 'Highlights'),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),

          // ── Tab content ──────────────────────────────────────────────────
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _TocTab(state: state),
                      _BookmarksSideTab(
                        bookmarks: _bookmarks,
                        state: state,
                        onRefresh: _loadBookmarks,
                      ),
                      _HighlightsSideTab(
                        highlights: state.highlights,
                        state: state,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ToC tab ────────────────────────────────────────────────────────────────────

class _TocTab extends StatelessWidget {
  final ReaderState state;
  const _TocTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (state.chapters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: state.chapters.length,
      itemBuilder: (context, index) {
        final ch = state.chapters[index];
        final isCurrent = state.currentChapter == index;
        return InkWell(
          onTap: () {
            context.read<ReaderCubit>().goToChapter(index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isCurrent ? 3 : 0,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (isCurrent) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ch.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                      color: isCurrent ? colorScheme.primary : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Bookmarks tab ───────────────────────────────────────────────────────────────

class _BookmarksSideTab extends StatelessWidget {
  final List<db_rec.Bookmark> bookmarks;
  final ReaderState state;
  final VoidCallback onRefresh;

  const _BookmarksSideTab({
    required this.bookmarks,
    required this.state,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 36,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No bookmarks yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: bookmarks.length,
      itemBuilder: (_, i) {
        final bm = bookmarks[i];
        final chTitle = readerChapterTitle(context, state, bm.chapterIndex);
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(Icons.bookmark_rounded,
              size: 16, color: colorScheme.primary),
          title: Text(bm.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(chTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11)),
          onTap: () {
            context.read<ReaderCubit>().goToChapter(bm.chapterIndex);
          },
        );
      },
    );
  }
}

// Highlights tab ──────────────────────────────────────────────────────────────

class _HighlightsSideTab extends StatelessWidget {
  final List<db_rec.Highlight> highlights;
  final ReaderState state;

  const _HighlightsSideTab({
    required this.highlights,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (highlights.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.highlight_off_rounded, size: 36,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No highlights yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: highlights.length,
      itemBuilder: (_, i) {
        final h = highlights[i];
        final chTitle = readerChapterTitle(context, state, h.chapterIndex);
        return InkWell(
          onTap: () => context.read<ReaderCubit>().goToHighlight(
              h.chapterIndex, h.selectedText),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _parseHighlightColor(h.color).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(
                      left: BorderSide(
                          color: _parseHighlightColor(h.color), width: 3),
                    ),
                  ),
                  child: Text(
                    h.selectedText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chTitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. _TopControls
// ---------------------------------------------------------------------------

class _TopControls extends StatelessWidget {
  final String title;
  final String chapterTitle;
  final VoidCallback? onZenMode;
  final VoidCallback? onToggleSidebar;
  final bool sidebarVisible;

  const _TopControls({
    required this.title,
    required this.chapterTitle,
    this.onZenMode,
    this.onToggleSidebar,
    this.sidebarVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.literata(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        chapterTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onToggleSidebar != null)
                  IconButton(
                    icon: Icon(
                      sidebarVisible
                          ? Icons.format_list_bulleted_rounded
                          : Icons.format_list_bulleted_rounded,
                      color: sidebarVisible ? Colors.white : Colors.white70,
                    ),
                    onPressed: onToggleSidebar,
                    tooltip: sidebarVisible ? 'Hide panel' : 'Show panel',
                  ),
                if (onZenMode != null)
                  IconButton(
                    icon: const Icon(Icons.spa_outlined, color: Colors.white),
                    onPressed: onZenMode,
                    tooltip: l10n.readerZenMode,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. _BottomControls — scrubber + simplified info
// ---------------------------------------------------------------------------

class _BottomControls extends StatelessWidget {
  final ReaderState state;
  final bool bookmarkConfirmed;
  final VoidCallback onToc;
  final VoidCallback onSettings;
  final VoidCallback onBookmark;
  final VoidCallback onAnnotations;
  final ValueChanged<int> onPageScrub;
  final ValueChanged<double> onBookScrub;

  const _BottomControls({
    required this.state,
    required this.bookmarkConfirmed,
    required this.onToc,
    required this.onSettings,
    required this.onBookmark,
    required this.onAnnotations,
    required this.onPageScrub,
    required this.onBookScrub,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalChapters = state.chapters.length;
    // Overall progress: 0.0 → 1.0 across entire book
    final overallProgress = totalChapters == 0
        ? 0.0
        : ((state.currentChapter + state.scrollProgress) / totalChapters).clamp(
            0.0,
            1.0,
          );
    final overallPercent = (overallProgress * 100).round();

    final chapterName = readerChapterTitle(
      context,
      state,
      state.currentChapter,
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Whole-book scrubber slider
                if (totalChapters > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                            activeTrackColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            thumbColor: Theme.of(context).colorScheme.primary,
                          ),
                          child: Slider(
                            value: overallProgress,
                            min: 0,
                            max: 1.0,
                            onChanged: (v) => onBookScrub(v),
                          ),
                        ),
                        Text(
                          l10n.readerChapterProgress(
                            chapterTitle: chapterName,
                            percent: overallPercent,
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.toc_rounded, color: Colors.white),
                      onPressed: onToc,
                      tooltip: l10n.readerTableOfContents,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                      ),
                      onPressed: onSettings,
                      tooltip: l10n.readerSettings,
                    ),
                    // Page within chapter
                    Flexible(
                      child: Text(
                        state.totalPages > 1
                            ? l10n.readerPageOf(
                                currentPage: state.currentPage + 1,
                                totalPages: state.totalPages,
                              )
                            : '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        bookmarkConfirmed
                            ? Icons.bookmark_added_rounded
                            : Icons.bookmark_add_outlined,
                        color: bookmarkConfirmed
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                      ),
                      onPressed: onBookmark,
                      tooltip: bookmarkConfirmed
                          ? l10n.readerBookmarkAdded
                          : l10n.readerBookmark,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.format_list_bulleted,
                        color: Colors.white,
                      ),
                      onPressed: onAnnotations,
                      tooltip: l10n.readerAnnotations,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. _ReaderSettingsSheet — typography + theme
// ---------------------------------------------------------------------------

class _ReaderSettingsSheet extends StatelessWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return BlocBuilder<ReaderCubit, ReaderState>(
      builder: (context, state) {
        final cubit = context.read<ReaderCubit>();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // -- Typography section --
                Text(
                  l10n.readerTypography,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Font family pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ReaderFontFamily.values.map((family) {
                      final isActive = family == state.fontFamily;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(readerFontFamilyLabel(context, family)),
                          selected: isActive,
                          onSelected: (_) => cubit.setFontFamily(family),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  l10n.readerReadingDirection,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ReaderDirectionOverride.values.map((direction) {
                      final isActive = direction == state.directionOverride;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(switch (direction) {
                            ReaderDirectionOverride.auto =>
                              l10n.readerDirectionAuto,
                            ReaderDirectionOverride.ltr =>
                              l10n.readerDirectionLeftToRight,
                            ReaderDirectionOverride.rtl =>
                              l10n.readerDirectionRightToLeft,
                          }),
                          selected: isActive,
                          onSelected: (_) =>
                              cubit.setDirectionOverride(direction),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Font size row + slider
                Row(
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.remove),
                      onPressed: () => cubit.setFontSize(state.fontSize - 1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.fontSize.round()}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.add),
                      onPressed: () => cubit.setFontSize(state.fontSize + 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: state.fontSize,
                        min: 12,
                        max: 32,
                        divisions: 20,
                        label: '${state.fontSize.round()}',
                        onChanged: (v) => cubit.setFontSize(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Line height
                Row(
                  children: [
                    Icon(
                      Icons.format_line_spacing,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: state.lineHeight,
                        min: 1.2,
                        max: 3.0,
                        divisions: 18,
                        label: state.lineHeight.toStringAsFixed(1),
                        onChanged: (v) => cubit.setLineHeight(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Margins
                Row(
                  children: [
                    Icon(
                      Icons.padding,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: state.horizontalMargin,
                        min: 8,
                        max: 48,
                        divisions: 8,
                        label: '${state.horizontalMargin.round()}',
                        onChanged: (v) => cubit.setHorizontalMargin(v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // -- Theme section --
                Text(
                  l10n.readerTheme,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ReaderTheme.values.map((theme) {
                    final isActive = theme == state.readerTheme;
                    return GestureDetector(
                      onTap: () => cubit.setReaderTheme(theme),
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
                          child: isActive
                              ? Icon(
                                  Icons.check,
                                  color: theme.textColor,
                                  size: 20,
                                )
                              : Icon(
                                  Icons.text_fields,
                                  color: theme.textColor,
                                  size: 18,
                                ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 6. _TocDrawer
// ---------------------------------------------------------------------------

class _TocDrawer extends StatelessWidget {
  final List<ChapterInfo> chapters;
  final int currentChapter;
  final void Function(int) onChapterTap;
  final VoidCallback onClose;

  const _TocDrawer({
    required this.chapters,
    required this.currentChapter,
    required this.onChapterTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {}, // prevent closing when tapping drawer
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                color: colorScheme.surface,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              l10n.readerContents,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: onClose,
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: chapters.length,
                          itemBuilder: (context, index) {
                            final chapter = chapters[index];
                            final isActive = index == currentChapter;

                            return ListTile(
                              title: Text(
                                chapter.title,
                                style: TextStyle(
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                              ),
                              selected: isActive,
                              selectedTileColor: colorScheme.primaryContainer
                                  .withValues(alpha: 0.3),
                              onTap: () => onChapterTap(index),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
