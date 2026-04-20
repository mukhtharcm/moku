import SwiftUI
import SwiftData
import WebKit

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReaderViewModel
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var selectedText: String?

    init(book: MokuBook) {
        _viewModel = State(initialValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack {
            // Reader WebView
            if viewModel.isLoading {
                ProgressView("Loading book…")
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            } else {
                ReaderWebView(viewModel: viewModel)
                    .ignoresSafeArea()
            }

            // Top controls overlay
            if viewModel.showControls && !viewModel.isZenMode {
                VStack {
                    readerToolbar
                    Spacer()
                    bottomBar
                }
            }
        }
        .onAppear { viewModel.loadBook() }
        .onDisappear { viewModel.saveProgress(modelContext: modelContext) }
        .onKeyPress(.leftArrow) { viewModel.previousChapter(); return .handled }
        .onKeyPress(.rightArrow) { viewModel.nextChapter(); return .handled }
        .sheet(isPresented: $showTOC) {
            tocSheet
        }
        .sheet(isPresented: $showSettings) {
            readerSettingsSheet
        }
    }

    // MARK: - Top Toolbar

    private var readerToolbar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                Text("Library")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.book.title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 16) {
                Button { showTOC.toggle() } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Table of Contents")

                Button { showSettings.toggle() } label: {
                    Image(systemName: "textformat.size")
                }
                .help("Reader Settings")

                Button {
                    viewModel.isZenMode.toggle()
                    viewModel.showControls = !viewModel.isZenMode
                } label: {
                    Image(systemName: viewModel.isZenMode ? "eye" : "eye.slash")
                }
                .help("Zen Mode")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button { viewModel.previousChapter() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.currentChapter <= 0)

            Spacer()

            VStack(spacing: 2) {
                if viewModel.currentChapter < viewModel.chapters.count {
                    Text(viewModel.chapters[viewModel.currentChapter].title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Spacer()

            Button { viewModel.nextChapter() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(viewModel.currentChapter >= viewModel.chapters.count - 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - TOC Sheet

    private var tocSheet: some View {
        VStack(alignment: .leading) {
            Text("Table of Contents")
                .font(.headline)
                .padding()

            List(viewModel.chapters, id: \.index) { chapter in
                Button {
                    viewModel.goToChapter(chapter.index)
                    showTOC = false
                } label: {
                    HStack {
                        Text(chapter.title)
                            .lineLimit(2)
                        Spacer()
                        if chapter.index == viewModel.currentChapter {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 350, height: 500)
    }

    // MARK: - Settings Sheet

    private var readerSettingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reader Settings")
                .font(.headline)
                .padding(.bottom, 8)

            // Font size
            HStack {
                Text("Font Size")
                Spacer()
                Slider(value: $viewModel.fontSize, in: 12...28, step: 1)
                    .frame(width: 200)
                Text("\(Int(viewModel.fontSize))px")
                    .monospacedDigit()
                    .frame(width: 40)
            }

            // Line height
            HStack {
                Text("Line Height")
                Spacer()
                Slider(value: $viewModel.lineHeight, in: 1.2...2.2, step: 0.1)
                    .frame(width: 200)
                Text(String(format: "%.1f", viewModel.lineHeight))
                    .monospacedDigit()
                    .frame(width: 40)
            }

            // Theme
            HStack {
                Text("Theme")
                Spacer()
                Picker("", selection: $viewModel.readerTheme) {
                    ForEach(ReaderViewModel.ReaderTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 450, height: 250)
    }
}

// MARK: - WebView

struct ReaderWebView: NSViewRepresentable {
    var viewModel: ReaderViewModel

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let handler = context.coordinator
        config.userContentController.add(handler, name: "MokuBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        loadContent(webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Reload when chapter changes
        if context.coordinator.lastChapter != viewModel.currentChapter ||
           context.coordinator.lastFontSize != viewModel.fontSize ||
           context.coordinator.lastTheme != viewModel.readerTheme.rawValue {
            loadContent(webView)
            context.coordinator.lastChapter = viewModel.currentChapter
            context.coordinator.lastFontSize = viewModel.fontSize
            context.coordinator.lastTheme = viewModel.readerTheme.rawValue
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    private func loadContent(_ webView: WKWebView) {
        guard let html = viewModel.getChapterHTML() else { return }
        webView.loadHTMLString(html, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var viewModel: ReaderViewModel
        weak var webView: WKWebView?
        var lastChapter: Int = -1
        var lastFontSize: Double = 0
        var lastTheme: String = ""

        init(viewModel: ReaderViewModel) {
            self.viewModel = viewModel
            self.lastChapter = viewModel.currentChapter
            self.lastFontSize = viewModel.fontSize
            self.lastTheme = viewModel.readerTheme.rawValue
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            Task { @MainActor in
                switch type {
                case "pageInfo":
                    if let current = json["currentPage"] as? Int,
                       let total = json["totalPages"] as? Int {
                        viewModel.currentPage = current
                        viewModel.totalPages = total
                    }
                case "nextChapter":
                    viewModel.nextChapter()
                case "prevChapter":
                    viewModel.previousChapter()
                case "selection":
                    if let text = json["text"] as? String {
                        // Could show highlight menu
                        print("Selected: \(text)")
                    }
                default:
                    break
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Content loaded
        }
    }
}
