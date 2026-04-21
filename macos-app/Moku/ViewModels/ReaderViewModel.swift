import SwiftUI
import SwiftData
import WebKit

@MainActor
@Observable
final class ReaderViewModel {
    var book: MokuBook
    var chapters: [ChapterInfo] = []
    var currentChapter: Int = 0
    var currentPage: Int = 1
    var totalPages: Int = 1
    var isLoading = true
    var errorMessage: String?
    var showControls = true
    var isZenMode = false

    // Reader settings
    var fontSize: Double = 18.0
    var lineHeight: Double = 1.6
    var horizontalMargin: Double = 48.0
    var fontFamily: ReaderFontFamily = .georgia
    var readerTheme: ReaderTheme = .system

    // Selection & annotation state
    var pendingSelection: String?
    var showHighlightBar = false
    var highlightVersion: Int = 0
    var editingHighlight: Highlight?
    var editNoteText: String = ""
    var showEditNote: Bool = false

    private let bookService = BookService()

    /// Whether this book uses the WebView reader (epub, txt, html)
    var usesWebViewReader: Bool {
        switch book.bookFormat {
        case .epub, .txt, .html: true
        case .pdf, .cbz: false
        }
    }

    var overallProgressForDisplay: Double {
        guard !chapters.isEmpty else { return 0 }
        let chapterProgress = totalPages > 1 ? Double(currentPage - 1) / Double(totalPages - 1) : 0.0
        return min(1.0, (Double(currentChapter) + chapterProgress) / Double(chapters.count))
    }

    enum ReaderFontFamily: String, CaseIterable {
        case georgia = "Georgia"
        case literata = "Literata"
        case merriweather = "Merriweather"
        case lora = "Lora"
        case system = "System"

        var cssFontFamily: String {
            switch self {
            case .georgia: "Georgia, serif"
            case .literata: "Literata, Georgia, serif"
            case .merriweather: "Merriweather, Georgia, serif"
            case .lora: "Lora, Georgia, serif"
            case .system: "-apple-system, sans-serif"
            }
        }

        var displayName: String { rawValue }
    }

    enum ReaderTheme: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case sepia = "Sepia"

        var backgroundColor: String {
            switch self {
            case .system: "#FFFFFF"
            case .light: "#FFFBF7"
            case .dark: "#1A1816"
            case .sepia: "#F4ECD8"
            }
        }

        var textColor: String {
            switch self {
            case .system: "#1C1917"
            case .light: "#2C2520"
            case .dark: "#D5D0CA"
            case .sepia: "#5B4636"
            }
        }
    }

    init(book: MokuBook) {
        self.book = book
        if let progress = book.readingProgress {
            currentChapter = progress.currentChapter
        }
    }

    func loadBook() {
        do {
            chapters = try bookService.getChapters(book: book)
            isLoading = false
        } catch {
            errorMessage = "Failed to load book: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func getChapterHTML() -> String? {
        do {
            let content = try bookService.getChapterContent(book: book, chapterIndex: currentChapter)
            return buildHTML(content: content)
        } catch {
            return "<p>Failed to load chapter: \(error.localizedDescription)</p>"
        }
    }

    func nextChapter() {
        if currentChapter < chapters.count - 1 {
            currentChapter += 1
            currentPage = 1
        }
    }

    func previousChapter() {
        if currentChapter > 0 {
            currentChapter -= 1
            currentPage = 1
        }
    }

    func goToChapter(_ index: Int) {
        guard index >= 0, index < chapters.count else { return }
        currentChapter = index
        currentPage = 1
    }

    func saveProgress(modelContext: ModelContext) {
        let chapterProgress = totalPages > 1 ? Double(currentPage - 1) / Double(totalPages - 1) : 0.0
        let overallProgress: Double
        if chapters.isEmpty {
            overallProgress = 0.0
        } else {
            overallProgress = (Double(currentChapter) + chapterProgress) / Double(chapters.count)
        }

        if let progress = book.readingProgress {
            progress.currentChapter = currentChapter
            progress.chapterProgress = chapterProgress
            progress.overallProgress = min(1.0, overallProgress)
            progress.lastReadAt = Date()
            progress.updatedAt = Date()
        } else {
            let progress = ReadingProgress(
                book: book,
                currentChapter: currentChapter,
                chapterProgress: chapterProgress,
                overallProgress: min(1.0, overallProgress)
            )
            modelContext.insert(progress)
        }

        book.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Bookmarks & Highlights

    var isCurrentChapterBookmarked: Bool {
        book.bookmarks.contains { $0.chapterIndex == currentChapter }
    }

    var highlightsForCurrentChapter: [Highlight] {
        book.highlights.filter { $0.chapterIndex == currentChapter }
    }

    var allHighlights: [Highlight] {
        book.highlights.sorted { $0.createdAt > $1.createdAt }
    }

    var allBookmarks: [BookmarkItem] {
        book.bookmarks.sorted { $0.createdAt > $1.createdAt }
    }

    func toggleBookmark(modelContext: ModelContext) {
        if let existing = book.bookmarks.first(where: { $0.chapterIndex == currentChapter }) {
            modelContext.delete(existing)
        } else {
            let title = currentChapter < chapters.count
                ? chapters[currentChapter].title
                : "Page \(currentChapter + 1)"
            let bookmark = BookmarkItem(book: book, chapterIndex: currentChapter, title: title)
            modelContext.insert(bookmark)
        }
        try? modelContext.save()
    }

    func addHighlight(text: String, color: String = "#FFEB3B", note: String? = nil, modelContext: ModelContext) {
        let highlight = Highlight(
            book: book,
            chapterIndex: currentChapter,
            selectedText: text,
            color: color,
            note: note
        )
        modelContext.insert(highlight)
        try? modelContext.save()
        pendingSelection = nil
        showHighlightBar = false
        highlightVersion += 1
    }

    func removeHighlight(_ highlight: Highlight, modelContext: ModelContext) {
        modelContext.delete(highlight)
        try? modelContext.save()
        highlightVersion += 1
    }

    func updateHighlightNote(_ highlight: Highlight, note: String?, modelContext: ModelContext) {
        highlight.note = note
        highlight.updatedAt = Date()
        try? modelContext.save()
    }

    // Navigation state
    var pendingHighlightText: String?
    var pendingFragment: String?
    var startFraction: Double? // fraction to restore on chapter load

    func goToChapterWithHighlight(_ index: Int, highlightText: String? = nil) {
        pendingHighlightText = highlightText
        goToChapter(index)
    }

    func goToChapterWithFragment(_ index: Int, fragment: String? = nil) {
        pendingFragment = fragment
        goToChapter(index)
    }

    private var startPositionJSON: String {
        if let fragment = pendingFragment {
            pendingFragment = nil
            return "{ \"type\": \"fragment\", \"value\": \"\(fragment)\" }"
        }
        if let fraction = startFraction, fraction > 0 {
            startFraction = nil
            return "{ \"type\": \"fraction\", \"value\": \(fraction) }"
        }
        return "null"
    }

    // MARK: - HTML Template

    private func buildHTML(content: String) -> String {
        let bgColor = readerTheme.backgroundColor
        let textColor = readerTheme.textColor
        let margin = Int(horizontalMargin)
        let fontFamilyCSS = fontFamily.cssFontFamily

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            * { box-sizing: border-box; }
            html, body {
                margin: 0; padding: 0;
                background-color: \(bgColor);
                color: \(textColor);
                overflow: hidden;
                height: 100vh;
            }
            #moku-content {
                font-family: \(fontFamilyCSS);
                font-size: \(fontSize)px;
                line-height: \(lineHeight);
                margin: 24px \(margin)px 48px \(margin)px;
                height: calc(100vh - 72px);
                column-width: calc(100vw - \(margin * 2)px);
                column-gap: \(margin * 2)px;
                column-fill: auto;
                overflow: hidden;
            }
            #moku-content img {
                max-width: 100%;
                height: auto;
                display: block;
                margin: 0.5em auto;
            }
            #moku-content h1, #moku-content h2, #moku-content h3 {
                font-family: "Georgia", serif;
                margin-top: 1em;
                margin-bottom: 0.5em;
            }
            #moku-content p {
                margin: 0 0 0.5em 0;
                text-align: justify;
                hyphens: auto;
            }
            mark[data-highlight-id] {
                border-radius: 2px;
                padding: 1px 0;
                cursor: pointer;
            }
        </style>
        </head>
        <body>
        <div id="moku-content">\(content)</div>
        <script>
        (function() {
            const content = document.getElementById('moku-content');
            const mokuPagination = {
                get totalPages() {
                    return Math.max(1, Math.ceil(content.scrollWidth / window.innerWidth));
                },
                get currentPage() {
                    const offset = Math.abs(
                        parseFloat(content.style.transform?.replace('translateX(', '').replace('px)', '') || '0')
                    );
                    return Math.round(offset / window.innerWidth) + 1;
                },
                goToPage(page) {
                    const p = Math.max(1, Math.min(page, this.totalPages));
                    const offset = (p - 1) * window.innerWidth;
                    content.style.transform = 'translateX(-' + offset + 'px)';
                    reportState();
                },
                nextPage() { this.goToPage(this.currentPage + 1); },
                prevPage() { this.goToPage(this.currentPage - 1); }
            };
            window.mokuPagination = mokuPagination;

            function reportState() {
                const msg = JSON.stringify({
                    type: 'pageInfo',
                    currentPage: mokuPagination.currentPage,
                    totalPages: mokuPagination.totalPages
                });
                window.webkit.messageHandlers.MokuBridge.postMessage(msg);
            }

            // Enhanced selection handler
            document.addEventListener('mouseup', function(e) {
                const sel = window.getSelection();
                if (sel && sel.toString().trim().length > 0) {
                    const msg = JSON.stringify({
                        type: 'selection',
                        text: sel.toString().trim()
                    });
                    window.webkit.messageHandlers.MokuBridge.postMessage(msg);
                } else {
                    window.webkit.messageHandlers.MokuBridge.postMessage(
                        JSON.stringify({ type: 'selectionCleared' })
                    );
                }
            });

            // Highlight application
            function mokuApplyHighlights(highlights) {
                highlights.forEach(function(hl) {
                    var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
                    var node;
                    var searchText = hl.text.substring(0, 80);
                    while (node = walker.nextNode()) {
                        var idx = node.textContent.indexOf(searchText);
                        if (idx >= 0) {
                            try {
                                var range = document.createRange();
                                var end = Math.min(idx + hl.text.length, node.textContent.length);
                                range.setStart(node, idx);
                                range.setEnd(node, end);
                                var mark = document.createElement('mark');
                                mark.style.backgroundColor = hl.color + '55';
                                mark.dataset.highlightId = hl.id;
                                range.surroundContents(mark);
                            } catch(e) {}
                            break;
                        }
                    }
                });
                setTimeout(reportState, 50);
            }

            document.addEventListener('keydown', function(e) {
                if (e.key === 'ArrowRight' || e.key === ' ') {
                    e.preventDefault();
                    if (mokuPagination.currentPage >= mokuPagination.totalPages) {
                        window.webkit.messageHandlers.MokuBridge.postMessage(
                            JSON.stringify({ type: 'nextChapter' })
                        );
                    } else {
                        mokuPagination.nextPage();
                    }
                } else if (e.key === 'ArrowLeft') {
                    e.preventDefault();
                    if (mokuPagination.currentPage <= 1) {
                        window.webkit.messageHandlers.MokuBridge.postMessage(
                            JSON.stringify({ type: 'prevChapter' })
                        );
                    } else {
                        mokuPagination.prevPage();
                    }
                }
            });

            // Apply saved highlights
            var mokuHighlights = \(highlightsJSON);
            setTimeout(function() { mokuApplyHighlights(mokuHighlights); }, 200);

            // Scroll to highlight text — called from native code
            window.scrollToHighlightText = function(text) {
                if (!text || text.length === 0) return;
                var content = document.getElementById('moku-content');
                if (!content) return;

                // First check existing highlight spans
                var spans = content.querySelectorAll('.moku-highlight, mark[data-highlight-id]');
                for (var i = 0; i < spans.length; i++) {
                    if (spans[i].textContent.indexOf(text) !== -1 || text.indexOf(spans[i].textContent) !== -1) {
                        var rect = spans[i].getBoundingClientRect();
                        var page = Math.floor(
                            (rect.left + mokuPagination.currentPage * window.innerWidth - 1) /
                            window.innerWidth
                        );
                        mokuPagination.goToPage(Math.max(1, page + 1));
                        return;
                    }
                }

                // Fallback: find text in DOM
                var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null, false);
                var allText = '';
                var nodes = [];
                while (walker.nextNode()) {
                    nodes.push({ node: walker.currentNode, start: allText.length });
                    allText += walker.currentNode.textContent;
                }
                var idx = allText.indexOf(text);
                if (idx === -1) return;

                for (var j = 0; j < nodes.length; j++) {
                    var n = nodes[j];
                    var nodeEnd = n.start + n.node.textContent.length;
                    if (nodeEnd > idx) {
                        try {
                            var range = document.createRange();
                            range.setStart(n.node, idx - n.start);
                            var rect = range.getBoundingClientRect();
                            var page = Math.floor(
                                (rect.left + mokuPagination.currentPage * window.innerWidth - 1) /
                                window.innerWidth
                            );
                            mokuPagination.goToPage(Math.max(1, page + 1));
                        } catch(e) {}
                        return;
                    }
                }
            };

            // Go to fragment (element ID)
            window.mokuGoToFragment = function(fragmentId) {
                var el = document.getElementById(fragmentId);
                if (!el) { mokuPagination.goToPage(1); return; }
                var rect = el.getBoundingClientRect();
                var page = Math.floor(
                    (rect.left + mokuPagination.currentPage * window.innerWidth - 1) /
                    window.innerWidth
                );
                mokuPagination.goToPage(Math.max(1, page + 1));
            };

            // Start position (restore, fraction, fragment)
            var mokuStartPos = \(startPositionJSON);
            if (mokuStartPos) {
                setTimeout(function() {
                    if (mokuStartPos.type === 'fraction' && mokuStartPos.value > 0) {
                        var page = Math.round(mokuStartPos.value * (mokuPagination.totalPages - 1)) + 1;
                        mokuPagination.goToPage(page);
                    } else if (mokuStartPos.type === 'fragment' && mokuStartPos.value) {
                        window.mokuGoToFragment(mokuStartPos.value);
                    }
                }, 300);
            }

            setTimeout(reportState, 100);
            window.addEventListener('resize', function() {
                setTimeout(reportState, 100);
            });
        })();
        </script>
        </body>
        </html>
        """
    }

    private var highlightsJSON: String {
        let highlights = highlightsForCurrentChapter
        if highlights.isEmpty { return "[]" }
        let items = highlights.map { hl in
            let escapedText = hl.selectedText
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            return "{\"id\":\"\(hl.id)\",\"text\":\"\(escapedText)\",\"color\":\"\(hl.color)\"}"
        }
        return "[\(items.joined(separator: ","))]"
    }
}
