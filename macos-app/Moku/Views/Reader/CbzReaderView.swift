import SwiftUI
import SwiftData

/// Comic book reader for CBZ files — image gallery with page navigation.
struct CbzReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ReaderViewModel
    @State private var currentImage: NSImage?
    @State private var controlsVisible = true
    @State private var zoomScale: CGFloat = 1.0

    init(book: MokuBook) {
        _viewModel = State(initialValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading comic…")
                    .foregroundStyle(.white)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                // Image display
                if let image = currentImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoomScale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onTapGesture {
                        withAnimation { controlsVisible.toggle() }
                    }
                } else {
                    Text("No image")
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Controls overlay
                if controlsVisible {
                    VStack {
                        cbzTopBar
                        Spacer()
                        cbzBottomBar
                    }
                }

                // Left/Right tap zones for navigation
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { previousPage() }
                        .frame(maxWidth: .infinity)

                    Color.clear
                        .frame(width: 200) // middle dead zone

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { nextPage() }
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            viewModel.loadBook()
            loadCurrentPage()
        }
        .onDisappear { viewModel.saveProgress(modelContext: modelContext) }
        .onChange(of: viewModel.currentChapter) { _, _ in loadCurrentPage() }
        .navigationTitle(viewModel.book.title)
        .onKeyPress(.leftArrow) { previousPage(); return .handled }
        .onKeyPress(.rightArrow) { nextPage(); return .handled }
        .onKeyPress(.upArrow) { zoomScale = min(3.0, zoomScale + 0.25); return .handled }
        .onKeyPress(.downArrow) { zoomScale = max(0.5, zoomScale - 0.25); return .handled }
        .focusedValue(\.readerActions, CbzReaderActionsHandler(
            viewModel: viewModel,
            modelContext: modelContext,
            controlsVisibleBinding: $controlsVisible
        ))
    }

    private func loadCurrentPage() {
        guard let filePath = viewModel.book.filePath else { return }
        let booksDir = BookService.booksDirectory()
        if let data = try? CbzParser.getPageImage(
            filePath: filePath,
            pageIndex: viewModel.currentChapter,
            booksDir: booksDir
        ) {
            currentImage = NSImage(data: data)
        } else {
            currentImage = nil
        }
    }

    private func nextPage() {
        if viewModel.currentChapter < viewModel.chapters.count - 1 {
            viewModel.currentChapter += 1
        }
    }

    private func previousPage() {
        if viewModel.currentChapter > 0 {
            viewModel.currentChapter -= 1
        }
    }

    private var cbzTopBar: some View {
        HStack {
            Button { NSApp.keyWindow?.close() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Library")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text(viewModel.book.title)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Button {
                viewModel.toggleBookmark(modelContext: modelContext)
            } label: {
                Image(systemName: viewModel.isCurrentChapterBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13))
                    .foregroundStyle(viewModel.isCurrentChapterBookmarked ? MokuTheme.coral : .white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Toggle Bookmark")

            Text("CBZ")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(MokuTheme.violet.opacity(0.3))
                .foregroundStyle(MokuTheme.violet)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.8), in: Rectangle())
    }

    private var cbzBottomBar: some View {
        VStack(spacing: 0) {
            if viewModel.chapters.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentChapter) },
                        set: { viewModel.currentChapter = Int($0) }
                    ),
                    in: 0...Double(max(1, viewModel.chapters.count - 1)),
                    step: 1
                )
                .tint(MokuTheme.violet)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            HStack {
                Button { previousPage() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(viewModel.currentChapter > 0 ? 0.8 : 0.2))
                .disabled(viewModel.currentChapter <= 0)

                Spacer()

                Text("Page \(viewModel.currentChapter + 1) of \(viewModel.chapters.count)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Button { nextPage() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(viewModel.currentChapter < viewModel.chapters.count - 1 ? 0.8 : 0.2))
                .disabled(viewModel.currentChapter >= viewModel.chapters.count - 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial.opacity(0.8), in: Rectangle())
    }
}

// MARK: - CBZ Reader Actions Handler

@MainActor
struct CbzReaderActionsHandler: ReaderActions {
    let viewModel: ReaderViewModel
    let modelContext: ModelContext
    @Binding var controlsVisibleBinding: Bool

    func toggleBookmark() {
        viewModel.toggleBookmark(modelContext: modelContext)
    }

    func showAnnotations() {
        // CBZ doesn't have annotations
    }

    func toggleZenMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsVisibleBinding.toggle()
        }
    }

    func increaseFontSize() {
        // Not applicable for CBZ
    }

    func decreaseFontSize() {
        // Not applicable for CBZ
    }

    func nextChapter() {
        viewModel.nextChapter()
    }

    func previousChapter() {
        viewModel.previousChapter()
    }
}
