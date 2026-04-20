import SwiftUI
import SwiftData
import WebKit

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: ReaderViewModel
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var showAnnotations = false
    @State private var controlsVisible = true
    @State private var controlsOpacity: Double = 1.0

    init(book: MokuBook) {
        _viewModel = State(initialValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack {
            // Background matches reader theme
            readerBackground.ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                // WebView content
                ReaderWebView(viewModel: viewModel)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            controlsVisible.toggle()
                            controlsOpacity = controlsVisible ? 1.0 : 0.0
                        }
                    }

                // Controls overlay
                if controlsVisible {
                    VStack(spacing: 0) {
                        topBar
                        Spacer()
                        bottomBar
                    }
                    .opacity(controlsOpacity)
                    .transition(.opacity)
                }

                // Highlight action bar
                if viewModel.showHighlightBar, let text = viewModel.pendingSelection {
                    VStack {
                        Spacer()
                        highlightActionBar(text: text)
                            .padding(.bottom, 70)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showHighlightBar)
                }
            }
        }
        .onAppear { viewModel.loadBook() }
        .onDisappear { viewModel.saveProgress(modelContext: modelContext) }
        .navigationTitle(viewModel.book.title)
        .sheet(isPresented: $showTOC) { tocSheet }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: $showAnnotations) { annotationsSheet }
        .focusedValue(\.readerActions, ReaderActionsHandler(
            viewModel: viewModel,
            modelContext: modelContext,
            showAnnotationsBinding: $showAnnotations,
            controlsVisibleBinding: $controlsVisible,
            controlsOpacityBinding: $controlsOpacity
        ))
    }

    private func closeWindow() {
        viewModel.saveProgress(modelContext: modelContext)
        NSApp.keyWindow?.close()
    }

    // MARK: - Background

    private var readerBackground: some View {
        Group {
            switch viewModel.readerTheme {
            case .system:
                colorScheme == .dark
                    ? Color(hex: "#1A1816")
                    : Color(hex: "#FFFBF7")
            case .light:
                Color(hex: "#FFFBF7")
            case .dark:
                Color(hex: "#1A1816")
            case .sepia:
                Color(hex: "#F4ECD8")
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading book…")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.orange.opacity(0.7))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Back to Library") { closeWindow() }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Back button
            Button { closeWindow() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Library")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary.opacity(0.7))

            Spacer()

            // Book title — centered
            Text(viewModel.book.title)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .lineLimit(1)
                .foregroundStyle(.primary.opacity(0.6))

            Spacer()

            // Action buttons
            HStack(spacing: 4) {
                toolbarButton(
                    icon: viewModel.isCurrentChapterBookmarked ? "bookmark.fill" : "bookmark",
                    help: "Toggle Bookmark (⌘D)"
                ) {
                    viewModel.toggleBookmark(modelContext: modelContext)
                }
                toolbarButton(icon: "highlighter", help: "Annotations") {
                    showAnnotations.toggle()
                }
                toolbarButton(icon: "list.bullet", help: "Contents") { showTOC.toggle() }
                toolbarButton(icon: "textformat.size", help: "Settings") { showSettings.toggle() }
                toolbarButton(icon: "eye.slash", help: "Zen Mode (hides controls)") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        controlsVisible = false
                        controlsOpacity = 0
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
    }

    private func toolbarButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.6))
        .help(help)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Reading progress slider
            if viewModel.chapters.count > 1 {
                HStack(spacing: 12) {
                    Text(chapterLabel(0))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)

                    Slider(
                        value: Binding(
                            get: { Double(viewModel.currentChapter) },
                            set: { viewModel.goToChapter(Int($0)) }
                        ),
                        in: 0...Double(max(1, viewModel.chapters.count - 1)),
                        step: 1
                    )
                    .tint(MokuTheme.coral.opacity(0.7))

                    Text(chapterLabel(viewModel.chapters.count - 1))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            HStack {
                // Previous chapter
                Button {
                    withAnimation { viewModel.previousChapter() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentChapter <= 0)
                .opacity(viewModel.currentChapter <= 0 ? 0.2 : 0.6)

                Spacer()

                // Chapter info
                VStack(spacing: 2) {
                    if viewModel.currentChapter < viewModel.chapters.count {
                        Text(viewModel.chapters[viewModel.currentChapter].title)
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .foregroundStyle(.primary.opacity(0.5))
                            .lineLimit(1)
                    }
                    Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Next chapter
                Button {
                    withAnimation { viewModel.nextChapter() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentChapter >= viewModel.chapters.count - 1)
                .opacity(viewModel.currentChapter >= viewModel.chapters.count - 1 ? 0.2 : 0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
    }

    private func chapterLabel(_ index: Int) -> String {
        guard index >= 0, index < viewModel.chapters.count else { return "" }
        return "\(index + 1)"
    }

    // MARK: - TOC Sheet

    private var tocSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Contents")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                Spacer()
                Button { showTOC = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollViewReader { proxy in
                List(viewModel.chapters, id: \.index) { chapter in
                    Button {
                        viewModel.goToChapter(chapter.index)
                        showTOC = false
                    } label: {
                        HStack(spacing: 10) {
                            // Chapter number
                            Text("\(chapter.index + 1)")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 24)

                            Text(chapter.title)
                                .font(.system(size: 13, weight: chapter.index == viewModel.currentChapter ? .semibold : .regular))
                                .foregroundStyle(chapter.index == viewModel.currentChapter ? MokuTheme.coral : .primary)
                                .lineLimit(2)

                            Spacer()

                            if chapter.index == viewModel.currentChapter {
                                Circle()
                                    .fill(MokuTheme.coral)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .id(chapter.index)
                }
                .listStyle(.plain)
                .onAppear {
                    proxy.scrollTo(viewModel.currentChapter, anchor: .center)
                }
            }
        }
        .frame(width: 380, height: 500)
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Reader Settings")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                Spacer()
                Button { showSettings = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            VStack(spacing: 20) {
                // Font size
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Text("A")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        Slider(value: $viewModel.fontSize, in: 14...26, step: 1)
                            .tint(MokuTheme.violet)
                        Text("A")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.tertiary)
                        Text("\(Int(viewModel.fontSize))")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 24)
                    }
                }

                // Line spacing
                VStack(alignment: .leading, spacing: 8) {
                    Text("Line Spacing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Slider(value: $viewModel.lineHeight, in: 1.2...2.2, step: 0.1)
                            .tint(MokuTheme.violet)
                        Text(String(format: "%.1f", viewModel.lineHeight))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 28)
                    }
                }

                // Theme selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Theme")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(ReaderViewModel.ReaderTheme.allCases, id: \.self) { theme in
                            ThemeSwatch(
                                theme: theme,
                                isSelected: viewModel.readerTheme == theme,
                                action: { viewModel.readerTheme = theme }
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .frame(width: 400, height: 300)
    }

    // MARK: - Highlight Action Bar

    private let mokuHighlightColors = ["#FFEB3B", "#FF8A65", "#81C784", "#64B5F6", "#CE93D8"]

    private func highlightActionBar(text: String) -> some View {
        HStack(spacing: 10) {
            ForEach(mokuHighlightColors, id: \.self) { color in
                Button {
                    viewModel.addHighlight(text: text, color: color, modelContext: modelContext)
                } label: {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 18)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                viewModel.pendingSelection = nil
                viewModel.showHighlightBar = false
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Copy")

            Button {
                viewModel.pendingSelection = nil
                viewModel.showHighlightBar = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    // MARK: - Annotations Sheet

    private var annotationsSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Annotations")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                Spacer()
                Button { showAnnotations = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Bookmarks section
                    if !viewModel.allBookmarks.isEmpty {
                        Text("BOOKMARKS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(viewModel.allBookmarks, id: \.id) { bookmark in
                            Button {
                                viewModel.goToChapter(bookmark.chapterIndex)
                                showAnnotations = false
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(MokuTheme.coral)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("Chapter \(bookmark.chapterIndex + 1)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(bookmark)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }

                    // Highlights section
                    if !viewModel.allHighlights.isEmpty {
                        Text("HIGHLIGHTS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(viewModel.allHighlights, id: \.id) { highlight in
                            Button {
                                viewModel.goToChapter(highlight.chapterIndex)
                                showAnnotations = false
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: highlight.color))
                                        .frame(width: 4, height: 36)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(highlight.selectedText)
                                            .font(.system(size: 12, design: .serif))
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .italic()
                                        if let note = highlight.note, !note.isEmpty {
                                            Text(note)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Text("Chapter \(highlight.chapterIndex + 1)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.removeHighlight(highlight, modelContext: modelContext)
                                }
                            }
                        }
                    }

                    if viewModel.allBookmarks.isEmpty && viewModel.allHighlights.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(.tertiary)
                            Text("No annotations yet")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("Select text to highlight, or tap the bookmark icon")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
            }
        }
        .frame(width: 380, height: 500)
    }
}

// MARK: - Theme Swatch

struct ThemeSwatch: View {
    let theme: ReaderViewModel.ReaderTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: theme.backgroundColor))
                    .frame(width: 48, height: 36)
                    .overlay(
                        Text("Aa")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundStyle(Color(hex: theme.textColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? MokuTheme.coral : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

                Text(theme.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? MokuTheme.coral : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
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
        if context.coordinator.lastChapter != viewModel.currentChapter ||
           context.coordinator.lastFontSize != viewModel.fontSize ||
           context.coordinator.lastLineHeight != viewModel.lineHeight ||
           context.coordinator.lastTheme != viewModel.readerTheme.rawValue ||
           context.coordinator.lastHighlightVersion != viewModel.highlightVersion {
            loadContent(webView)
            context.coordinator.lastChapter = viewModel.currentChapter
            context.coordinator.lastFontSize = viewModel.fontSize
            context.coordinator.lastLineHeight = viewModel.lineHeight
            context.coordinator.lastTheme = viewModel.readerTheme.rawValue
            context.coordinator.lastHighlightVersion = viewModel.highlightVersion
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
        var lastLineHeight: Double = 0
        var lastTheme: String = ""
        var lastHighlightVersion: Int = 0

        init(viewModel: ReaderViewModel) {
            self.viewModel = viewModel
            self.lastChapter = viewModel.currentChapter
            self.lastFontSize = viewModel.fontSize
            self.lastLineHeight = viewModel.lineHeight
            self.lastTheme = viewModel.readerTheme.rawValue
            self.lastHighlightVersion = viewModel.highlightVersion
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
                        viewModel.pendingSelection = text
                        viewModel.showHighlightBar = true
                    }
                case "selectionCleared":
                    viewModel.pendingSelection = nil
                    viewModel.showHighlightBar = false
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

// MARK: - Reader Actions Handler

@MainActor
struct ReaderActionsHandler: ReaderActions {
    let viewModel: ReaderViewModel
    let modelContext: ModelContext
    @Binding var showAnnotationsBinding: Bool
    @Binding var controlsVisibleBinding: Bool
    @Binding var controlsOpacityBinding: Double

    func toggleBookmark() {
        viewModel.toggleBookmark(modelContext: modelContext)
    }

    func showAnnotations() {
        showAnnotationsBinding.toggle()
    }

    func toggleZenMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsVisibleBinding.toggle()
            controlsOpacityBinding = controlsVisibleBinding ? 1.0 : 0.0
        }
    }

    func increaseFontSize() {
        viewModel.fontSize = min(32, viewModel.fontSize + 1)
    }

    func decreaseFontSize() {
        viewModel.fontSize = max(12, viewModel.fontSize - 1)
    }

    func nextChapter() {
        viewModel.nextChapter()
    }

    func previousChapter() {
        viewModel.previousChapter()
    }
}
