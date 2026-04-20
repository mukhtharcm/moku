import SwiftUI
import SwiftData
import PDFKit

/// Native PDF reader using macOS PDFKit.
struct PdfReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: ReaderViewModel
    @State private var pdfDocument: PDFDocument?
    @State private var controlsVisible = true
    @State private var showAnnotations = false

    init(book: MokuBook) {
        _viewModel = State(initialValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack {
            Color(hex: viewModel.readerTheme == .dark ? "#1A1816" : "#F5F5F5")
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading PDF…")
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.orange.opacity(0.7))
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } else if let doc = pdfDocument {
                PdfKitView(document: doc, viewModel: viewModel)
                    .ignoresSafeArea()

                if controlsVisible {
                    VStack {
                        pdfTopBar
                        Spacer()
                        pdfBottomBar
                    }
                }
            }
        }
        .onAppear { loadPdf() }
        .onDisappear { viewModel.saveProgress(modelContext: modelContext) }
        .navigationTitle(viewModel.book.title)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                controlsVisible.toggle()
            }
        }
        .focusedValue(\.readerActions, PdfReaderActionsHandler(
            viewModel: viewModel,
            modelContext: modelContext,
            controlsVisibleBinding: $controlsVisible
        ))
    }

    private func loadPdf() {
        viewModel.loadBook()
        guard let filePath = viewModel.book.filePath else { return }
        let url = BookService.booksDirectory().appendingPathComponent(filePath)
        pdfDocument = PDFDocument(url: url)
    }

    private var pdfTopBar: some View {
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
            .foregroundStyle(.primary.opacity(0.7))

            Spacer()

            Text(viewModel.book.title)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .lineLimit(1)
                .foregroundStyle(.primary.opacity(0.6))

            Spacer()

            Button {
                viewModel.toggleBookmark(modelContext: modelContext)
            } label: {
                Image(systemName: viewModel.isCurrentChapterBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13))
                    .foregroundStyle(viewModel.isCurrentChapterBookmarked ? MokuTheme.coral : .primary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Toggle Bookmark")

            Text("PDF")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(MokuTheme.coral.opacity(0.15))
                .foregroundStyle(MokuTheme.coral)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Rectangle())
    }

    private var pdfBottomBar: some View {
        HStack {
            Spacer()
            if let doc = pdfDocument {
                Text("Page \(viewModel.currentChapter + 1) of \(doc.pageCount)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Rectangle())
    }
}

/// NSViewRepresentable wrapper for PDFKit's PDFView.
struct PdfKitView: NSViewRepresentable {
    let document: PDFDocument
    var viewModel: ReaderViewModel

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear

        // Restore to saved page
        if viewModel.currentChapter > 0, viewModel.currentChapter < document.pageCount {
            if let page = document.page(at: viewModel.currentChapter) {
                pdfView.go(to: page)
            }
        }

        // Observe page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Nothing to update dynamically
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, document: document)
    }

    @MainActor
    class Coordinator: NSObject {
        var viewModel: ReaderViewModel
        let document: PDFDocument
        weak var pdfView: PDFView?

        init(viewModel: ReaderViewModel, document: PDFDocument) {
            self.viewModel = viewModel
            self.document = document
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage,
                  let pageIndex = document.index(for: currentPage) as Int? else { return }
            viewModel.currentChapter = pageIndex
            viewModel.totalPages = document.pageCount
            viewModel.currentPage = pageIndex + 1
        }
    }
}

// MARK: - PDF Reader Actions Handler

@MainActor
struct PdfReaderActionsHandler: ReaderActions {
    let viewModel: ReaderViewModel
    let modelContext: ModelContext
    @Binding var controlsVisibleBinding: Bool

    func toggleBookmark() {
        viewModel.toggleBookmark(modelContext: modelContext)
    }

    func showAnnotations() {
        // PDF doesn't have a full annotations sheet yet
    }

    func toggleZenMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsVisibleBinding.toggle()
        }
    }

    func increaseFontSize() {
        // Not applicable for PDF
    }

    func decreaseFontSize() {
        // Not applicable for PDF
    }

    func nextChapter() {
        viewModel.nextChapter()
    }

    func previousChapter() {
        viewModel.previousChapter()
    }
}
