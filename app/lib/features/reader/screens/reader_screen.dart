import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/database/database.dart'
    hide Book, Bookmark, Highlight, BookCollection;
import '../../../core/models/book.dart';
import '../../../core/services/epub_service.dart';
import '../../../core/theme/app_theme.dart';
import '../cubit/reader_cubit.dart';
import '../cubit/reader_state.dart';
import 'annotations_screen.dart';

// ---------------------------------------------------------------------------
// 1. ReaderScreen — entry point, creates BlocProvider
// ---------------------------------------------------------------------------

class ReaderScreen extends StatelessWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReaderCubit(
        database: context.read<AppDatabase>(),
        epubService: context.read<EpubService>(),
        book: book,
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
    with SingleTickerProviderStateMixin {
  late WebViewController _webController;
  bool _webViewReady = false;

  // Selection state for highlight toolbar
  String? _selectedText;
  int? _selectionStartOffset;
  int? _selectionEndOffset;

  // Track last loaded state to avoid redundant reloads
  String _lastLoadedContent = '';
  double _lastLoadedFontSize = 0;
  double _lastLoadedLineHeight = 0;
  double _lastLoadedMargin = 0;
  ReaderFontFamily? _lastLoadedFontFamily;
  ReaderTheme? _lastLoadedTheme;

  // Pagination start position: 'restore', 'first', 'last', 'fraction:X', 'fragment:id'
  String _pendingStartPosition = 'restore';

  // Zen‑mode hint animation
  late AnimationController _zenHintController;
  late Animation<double> _zenHintOpacity;
  Timer? _zenHintTimer;
  bool _zenHintVisible = false;

  @override
  void initState() {
    super.initState();

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
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'MokuBridge',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _webViewReady = true);
            // Highlights are applied after content loads; pagination JS is in the HTML template
            final state = context.read<ReaderCubit>().state;
            _applyHighlightsToWebView(state.highlights);
          },
        ),
      );
  }

  @override
  void dispose() {
    _zenHintTimer?.cancel();
    _zenHintController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // -- Zen hint helpers ----------------------------------------------------

  void _showZenHint() {
    _zenHintTimer?.cancel();
    _zenHintController.reset();
    setState(() => _zenHintVisible = true);
    _zenHintTimer = Timer(const Duration(seconds: 2), () {
      _zenHintController.forward().then((_) {
        if (mounted) setState(() => _zenHintVisible = false);
      });
    });
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
        // Single center-tap exits zen mode (more discoverable than double-tap)
        cubit.toggleZenMode();
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
      _webController
          .runJavaScript('if(typeof clearHighlights==="function") clearHighlights();');
      return;
    }
    final highlightData = highlights
        .map((h) => {
              'text': h.selectedText,
              'id': h.id,
              'color': h.color,
            })
        .toList();
    final jsonStr = json.encode(highlightData);
    final escaped = jsonStr.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    _webController.runJavaScript(
        "if(typeof applyHighlights==='function') applyHighlights('$escaped');");
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
                  '"$text"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.highlight),
                title: const Text('Highlight'),
                onTap: () {
                  Navigator.pop(ctx);
                  context
                      .read<ReaderCubit>()
                      .addHighlight(text, startOffset, endOffset);
                  _clearSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('Highlight with Note'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddNoteDialog(context, text, startOffset, endOffset);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  _clearSelection();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
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
      BuildContext context, String text, int startOffset, int endOffset) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$text"',
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
              final cubit = context.read<ReaderCubit>();
              await cubit.addHighlight(text, startOffset, endOffset);
              if (noteController.text.isNotEmpty) {
                final highlights = cubit.state.highlights;
                if (highlights.isNotEmpty) {
                  final lastHighlight = highlights.last;
                  await cubit.updateHighlightNote(
                      lastHighlight.id, noteController.text);
                }
              }
              _clearSelection();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // -- HTML content --------------------------------------------------------

  void _loadContent(ReaderState state, {String startPosition = 'first'}) {
    setState(() => _webViewReady = false);
    final html = _wrapHtml(state.currentContent, state, startPosition: startPosition);
    _webController.loadHtmlString(html);
  }

  String _wrapHtml(String content, ReaderState state, {String startPosition = 'first'}) {
    final bgColor = _colorToHex(state.readerTheme.backgroundColor);
    final textColor = _colorToHex(state.readerTheme.textColor);
    final fontFamily = state.fontFamily.cssFontFamily;
    final fontSize = state.fontSize;
    final lineHeight = state.lineHeight;
    final hMargin = state.horizontalMargin.toInt();
    final colWidth = 'calc(100vw - ${2 * hMargin}px)';
    final colGap = '${2 * hMargin}px';

    // Build start position JS object
    String startPosJs;
    if (startPosition == 'last') {
      startPosJs = "{ type: 'last' }";
    } else if (startPosition.startsWith('fraction:')) {
      startPosJs = "{ type: 'fraction', value: ${startPosition.substring(9)} }";
    } else if (startPosition.startsWith('fragment:')) {
      startPosJs = "{ type: 'fragment', value: '${startPosition.substring(9)}' }";
    } else {
      startPosJs = "{ type: 'first' }";
    }

    return '''
<!DOCTYPE html>
<html>
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
    border-left: 3px solid $textColor;
    opacity: 0.8;
    padding-left: 16px;
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
$content
  </div>
</div>
<script>
// --- Start position ---
window._mokuStartPosition = $startPosJs;

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
    if (dx < 0) mokuPagination.nextPage();
    else mokuPagination.prevPage();
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
        if (zone === 'left') mokuPagination.prevPage();
        else if (zone === 'right') mokuPagination.nextPage();
        else MokuBridge.postMessage('tap');
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
          prev.highlights != curr.highlights ||
          prev.zenMode != curr.zenMode,
      listener: (context, state) {
        // Show zen hint when entering zen mode
        if (state.zenMode && !_zenHintVisible) {
          _showZenHint();
        }

        final contentChanged = state.currentContent != _lastLoadedContent;
        final settingsChanged = state.fontSize != _lastLoadedFontSize ||
            state.lineHeight != _lastLoadedLineHeight ||
            state.horizontalMargin != _lastLoadedMargin ||
            state.fontFamily != _lastLoadedFontFamily ||
            state.readerTheme != _lastLoadedTheme;

        if (state.currentContent.isNotEmpty && (contentChanged || settingsChanged)) {
          _lastLoadedContent = state.currentContent;
          _lastLoadedFontSize = state.fontSize;
          _lastLoadedLineHeight = state.lineHeight;
          _lastLoadedMargin = state.horizontalMargin;
          _lastLoadedFontFamily = state.fontFamily;
          _lastLoadedTheme = state.readerTheme;

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
        }
      },
      builder: (context, state) {
        if (state.status == ReaderStatus.loading) {
          return Scaffold(
            backgroundColor: state.readerTheme.backgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == ReaderStatus.error) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text(state.errorMessage ?? 'Unknown error')),
          );
        }

        if (state.zenMode) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        return Scaffold(
          backgroundColor: state.readerTheme.backgroundColor,
          body: Stack(
            children: [
              // WebView reader — always respect top safe area to avoid notch
              SafeArea(
                top: true,
                bottom: !state.zenMode,
                child: WebViewWidget(controller: _webController),
              ),

              // Top controls
              if (state.showControls && !state.zenMode)
                _TopControls(
                  title: state.book.title,
                  chapterTitle: state.chapterTitle,
                  onZenMode: () =>
                      context.read<ReaderCubit>().toggleZenMode(),
                ),

              // Bottom controls
              if (state.showControls && !state.zenMode)
                _BottomControls(
                  state: state,
                  onToc: () =>
                      context.read<ReaderCubit>().toggleToc(),
                  onSettings: () => _showSettingsSheet(context),
                  onBookmark: () => context
                      .read<ReaderCubit>()
                      .addBookmark(state.chapterTitle),
                  onAnnotations: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ReaderCubit>(),
                        child: AnnotationsScreen(book: state.book),
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
                    label: const Text('Highlight'),
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
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),

              // Zen mode exit hint — fades in then out
              if (state.zenMode && _zenHintVisible)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FadeTransition(
                      opacity: _zenHintOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Double-tap to exit zen mode',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<ReaderCubit>(),
        child: const _ReaderSettingsSheet(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. _TopControls
// ---------------------------------------------------------------------------

class _TopControls extends StatelessWidget {
  final String title;
  final String chapterTitle;
  final VoidCallback? onZenMode;

  const _TopControls({
    required this.title,
    required this.chapterTitle,
    this.onZenMode,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
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
                if (onZenMode != null)
                  IconButton(
                    icon: const Icon(Icons.spa_outlined, color: Colors.white),
                    onPressed: onZenMode,
                    tooltip: 'Zen Mode',
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
// 4. _BottomControls — redesigned single row
// ---------------------------------------------------------------------------

class _BottomControls extends StatelessWidget {
  final ReaderState state;
  final VoidCallback onToc;
  final VoidCallback onSettings;
  final VoidCallback onBookmark;
  final VoidCallback onAnnotations;

  const _BottomControls({
    required this.state,
    required this.onToc,
    required this.onSettings,
    required this.onBookmark,
    required this.onAnnotations,
  });

  @override
  Widget build(BuildContext context) {
    final pagesLeft = state.totalPages - state.currentPage - 1;
    final pageText = state.totalPages > 1
        ? pagesLeft == 0
            ? 'Last page of chapter'
            : '$pagesLeft page${pagesLeft == 1 ? '' : 's'} left in chapter'
        : '';

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
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page info — Apple Books style
                if (pageText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      pageText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.toc_rounded,
                          color: Colors.white),
                      onPressed: onToc,
                      tooltip: 'Table of Contents',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.white),
                      onPressed: onSettings,
                      tooltip: 'Settings',
                    ),
                    // Chapter & page info
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ch ${state.currentChapter + 1} of ${state.chapters.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (state.totalPages > 1)
                            Text(
                              '${state.currentPage + 1} / ${state.totalPages}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined,
                          color: Colors.white),
                      onPressed: onBookmark,
                      tooltip: 'Bookmark',
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_list_bulleted,
                          color: Colors.white),
                      onPressed: onAnnotations,
                      tooltip: 'Annotations',
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
                  'Typography',
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
                          label: Text(family.displayName),
                          selected: isActive,
                          onSelected: (_) => cubit.setFontFamily(family),
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
                      icon: const Text('A-',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () =>
                          cubit.setFontSize(state.fontSize - 1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.fontSize.round()}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Text('A+',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () =>
                          cubit.setFontSize(state.fontSize + 1),
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
                    Icon(Icons.format_line_spacing,
                        size: 20, color: colorScheme.onSurfaceVariant),
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
                    Icon(Icons.padding,
                        size: 20, color: colorScheme.onSurfaceVariant),
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
                  'Theme',
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
                              ? Icon(Icons.check,
                                  color: theme.textColor, size: 20)
                              : Text(
                                  'Aa',
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
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
  final List<EpubChapterInfo> chapters;
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
                              'Contents',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: onClose,
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
