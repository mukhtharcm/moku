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
import '../../../core/theme/theme_cubit.dart';
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
            _injectScrollListener();
            _injectSelectionListener();
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
    if (data.startsWith('scroll:')) {
      final progress = double.tryParse(data.substring(7)) ?? 0.0;
      context.read<ReaderCubit>().updateScrollProgress(progress);
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

  void _injectScrollListener() {
    final powerSaver = context.read<ThemeCubit>().state.powerSaver;
    final throttleMs = powerSaver ? 1000 : 200;

    _webController.runJavaScript('''
      var _mokuScrollTimer = null;
      window.addEventListener('scroll', function() {
        if (_mokuScrollTimer) return;
        _mokuScrollTimer = setTimeout(function() {
          _mokuScrollTimer = null;
          var scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
          var scrollHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
          var progress = scrollHeight > 0 ? scrollTop / scrollHeight : 0;
          MokuBridge.postMessage('scroll:' + progress.toFixed(4));
        }, $throttleMs);
      });
    ''');
  }

  void _injectSelectionListener() {
    _webController.runJavaScript('''
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
    ''');
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

  void _loadContent(ReaderState state) {
    final html = _wrapHtml(state.currentContent, state);
    _webController.loadHtmlString(html);
  }

  String _wrapHtml(String content, ReaderState state) {
    final bgColor = _colorToHex(state.readerTheme.backgroundColor);
    final textColor = _colorToHex(state.readerTheme.textColor);
    final fontFamily = state.fontFamily.cssFontFamily;
    final fontSize = state.fontSize;
    final lineHeight = state.lineHeight;
    final hMargin = state.horizontalMargin;

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  * { box-sizing: border-box; }
  body {
    background-color: $bgColor !important;
    color: $textColor !important;
    font-family: $fontFamily !important;
    font-size: ${fontSize}px !important;
    line-height: $lineHeight !important;
    padding: 20px ${hMargin}px 60px ${hMargin}px !important;
    word-wrap: break-word;
    overflow-wrap: break-word;
    -webkit-text-size-adjust: none;
  }
  h1, h2, h3, h4, h5, h6 {
    margin: 1em 0 0.5em 0;
    line-height: 1.3;
  }
  h1 { font-size: 1.6em; }
  h2 { font-size: 1.4em; }
  h3 { font-size: 1.2em; }
  p { margin: 0.8em 0; text-align: justify; }
  img { max-width: 100%; height: auto; display: block; margin: 1em auto; }
  a { color: inherit; text-decoration: underline; }
  blockquote {
    border-left: 3px solid $textColor;
    opacity: 0.8;
    padding-left: 16px;
    margin: 1em 0;
  }
  pre, code {
    font-family: monospace;
    font-size: 0.9em;
    background: rgba(128,128,128,0.1);
    padding: 2px 4px;
    border-radius: 3px;
  }
  pre { padding: 12px; overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; margin: 1em 0; }
  td, th { border: 1px solid rgba(128,128,128,0.3); padding: 8px; }
  .moku-highlight {
    background-color: rgba(255, 235, 59, 0.4);
    border-radius: 2px;
    cursor: pointer;
  }
</style>
</head>
<body>
$content
<script>
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
  var bodyText = document.body.innerText;
  var idx = bodyText.indexOf(text);
  if (idx === -1) return;

  var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
  var charCount = 0;
  var startNode = null, startOff = 0, endNode = null, endOff = 0;
  var targetEnd = idx + text.length;

  while (walker.nextNode()) {
    var node = walker.currentNode;
    var nodeLen = node.textContent.length;
    if (!startNode && charCount + nodeLen > idx) {
      startNode = node;
      startOff = idx - charCount;
    }
    if (charCount + nodeLen >= targetEnd) {
      endNode = node;
      endOff = targetEnd - charCount;
      break;
    }
    charCount += nodeLen;
  }

  if (!startNode || !endNode) return;

  try {
    var range = document.createRange();
    range.setStart(startNode, startOff);
    range.setEnd(endNode, endOff);
    var span = document.createElement('span');
    span.className = 'moku-highlight';
    span.dataset.highlightId = id || '';
    if (color) {
      var r = parseInt(color.substr(1,2), 16);
      var g = parseInt(color.substr(3,2), 16);
      var b = parseInt(color.substr(5,2), 16);
      span.style.backgroundColor = 'rgba(' + r + ',' + g + ',' + b + ',0.4)';
    }
    range.surroundContents(span);
  } catch(e) {}
}
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

        final contentChanged = state.currentContent != _lastLoadedContent ||
            state.fontSize != _lastLoadedFontSize ||
            state.lineHeight != _lastLoadedLineHeight ||
            state.horizontalMargin != _lastLoadedMargin ||
            state.fontFamily != _lastLoadedFontFamily ||
            state.readerTheme != _lastLoadedTheme;

        if (state.currentContent.isNotEmpty && contentChanged) {
          _lastLoadedContent = state.currentContent;
          _lastLoadedFontSize = state.fontSize;
          _lastLoadedLineHeight = state.lineHeight;
          _lastLoadedMargin = state.horizontalMargin;
          _lastLoadedFontFamily = state.fontFamily;
          _lastLoadedTheme = state.readerTheme;
          _loadContent(state);
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
              // WebView reader
              GestureDetector(
                onTap: () {
                  if (state.zenMode) {
                    // Single tap in zen mode: briefly show the hint again
                    _showZenHint();
                  } else {
                    context.read<ReaderCubit>().toggleControls();
                  }
                },
                onDoubleTap: () {
                  if (state.zenMode) {
                    context.read<ReaderCubit>().toggleZenMode();
                  }
                },
                child: SafeArea(
                  top: !state.zenMode,
                  bottom: !state.zenMode,
                  child: WebViewWidget(controller: _webController),
                ),
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
                  onPrevious: state.hasPreviousChapter
                      ? () => context.read<ReaderCubit>().previousChapter()
                      : null,
                  onNext: state.hasNextChapter
                      ? () => context.read<ReaderCubit>().nextChapter()
                      : null,
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
                  onChapterTap: (index) =>
                      context.read<ReaderCubit>().goToChapter(index),
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
                    minHeight: state.zenMode ? 1.5 : 2,
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
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSettings;
  final VoidCallback onBookmark;
  final VoidCallback onAnnotations;

  const _BottomControls({
    required this.state,
    this.onPrevious,
    this.onNext,
    required this.onSettings,
    required this.onBookmark,
    required this.onAnnotations,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.navigate_before, color: Colors.white),
                  onPressed: onPrevious,
                  tooltip: 'Previous chapter',
                ),
                Text(
                  '${state.currentChapter + 1} / ${state.chapters.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white),
                  onPressed: onSettings,
                  tooltip: 'Settings',
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
                IconButton(
                  icon: const Icon(Icons.navigate_next, color: Colors.white),
                  onPressed: onNext,
                  tooltip: 'Next chapter',
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
