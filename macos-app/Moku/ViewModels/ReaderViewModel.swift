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
    var readerTheme: ReaderTheme = .system

    private let bookService = BookService()

    /// Whether this book uses the WebView reader (epub, txt, html)
    var usesWebViewReader: Bool {
        switch book.bookFormat {
        case .epub, .txt, .html: true
        case .pdf, .cbz: false
        }
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

    // MARK: - HTML Template

    private func buildHTML(content: String) -> String {
        let bgColor = readerTheme.backgroundColor
        let textColor = readerTheme.textColor
        let margin = 48

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
                font-family: "Georgia", "Literata", serif;
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
            .moku-highlight {
                background-color: rgba(255, 235, 59, 0.4);
                border-radius: 2px;
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

            document.addEventListener('mouseup', function(e) {
                const sel = window.getSelection();
                if (sel && sel.toString().trim().length > 0) {
                    const msg = JSON.stringify({
                        type: 'selection',
                        text: sel.toString().trim()
                    });
                    window.webkit.messageHandlers.MokuBridge.postMessage(msg);
                }
            });

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
}
