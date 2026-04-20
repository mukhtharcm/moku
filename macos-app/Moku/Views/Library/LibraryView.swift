import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @State private var selectedBook: MokuBook?
    @State private var openedBook: MokuBook?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            libraryToolbar

            Divider()

            if viewModel.filteredBooks.isEmpty && viewModel.searchQuery.isEmpty {
                emptyState
            } else if viewModel.filteredBooks.isEmpty {
                noResults
            } else {
                bookContent
            }
        }
        .onAppear { viewModel.setup(modelContext: modelContext) }
        .onReceive(NotificationCenter.default.publisher(for: .triggerImport)) { _ in
            viewModel.importBook()
        }
        .onDrop(of: [.epub, .fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .sheet(item: $openedBook) { book in
            ReaderView(book: book)
                .frame(minWidth: 700, minHeight: 500)
        }
    }

    // MARK: - Toolbar

    private var libraryToolbar: some View {
        HStack(spacing: 12) {
            Text("Library")
                .font(.system(size: 20, weight: .bold, design: .serif))

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search books…", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            // Sort
            Menu {
                ForEach(LibraryViewModel.SortMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.sortMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: viewModel.sortMode == mode ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }

            // View mode toggle
            Picker("View", selection: $viewModel.viewMode) {
                Image(systemName: "square.grid.2x2").tag(LibraryViewModel.ViewMode.grid)
                Image(systemName: "list.bullet").tag(LibraryViewModel.ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            // Import button
            Button {
                viewModel.importBook()
            } label: {
                Image(systemName: "plus")
            }
            .help("Import EPUB (⌘O)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var bookContent: some View {
        switch viewModel.viewMode {
        case .grid:
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160, maximum: 200))],
                    spacing: 20
                ) {
                    ForEach(viewModel.filteredBooks, id: \.id) { book in
                        BookGridItem(book: book)
                            .onTapGesture(count: 2) { openedBook = book }
                            .onTapGesture(count: 1) { selectedBook = book }
                            .contextMenu { bookContextMenu(book) }
                    }
                }
                .padding(20)
            }
        case .list:
            List(viewModel.filteredBooks, id: \.id, selection: $selectedBook) { book in
                BookListRow(book: book)
                    .onTapGesture(count: 2) { openedBook = book }
                    .contextMenu { bookContextMenu(book) }
            }
        }
    }

    private func bookContextMenu(_ book: MokuBook) -> some View {
        Group {
            Button("Open") { openedBook = book }
            Divider()
            Button("Delete", role: .destructive) { viewModel.deleteBook(book) }
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Your Library Awaits")
                .font(.system(size: 22, weight: .semibold, design: .serif))
            Text("Import EPUB files to start reading")
                .foregroundStyle(.secondary)

            Button("Import EPUB") { viewModel.importBook() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)

            Text("Or drag and drop files here")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No books found")
                .font(.headline)
            Text("Try a different search term")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Drop

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                if url.pathExtension.lowercased() == "epub" {
                    Task { @MainActor in
                        do {
                            let epubService = EpubService()
                            let book = try epubService.importEpub(from: url)
                            modelContext.insert(book)
                            try modelContext.save()
                            viewModel.loadBooks()
                        } catch {
                            print("Drop import failed: \(error)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Grid Item

struct BookGridItem: View {
    let book: MokuBook

    var body: some View {
        VStack(spacing: 8) {
            BookCoverView(coverPath: book.coverPath, title: book.title)
                .frame(width: 140, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            VStack(spacing: 2) {
                Text(book.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(book.author)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
    }
}

// MARK: - List Row

struct BookListRow: View {
    let book: MokuBook

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(coverPath: book.coverPath, title: book.title)
                .frame(width: 40, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(book.author)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let progress = book.readingProgress {
                Text("\(Int(progress.overallProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Book Cover

struct BookCoverView: View {
    let coverPath: String?
    let title: String

    var body: some View {
        if let coverPath,
           let coverURL = EpubService.coverURL(for: coverPath),
           let image = NSImage(contentsOf: coverURL) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Placeholder cover
            ZStack {
                LinearGradient(
                    colors: [placeholderColor, placeholderColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 4) {
                    Image(systemName: "book.closed")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    private var placeholderColor: Color {
        let hash = title.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.4, brightness: 0.6)
    }
}

// MARK: - UTType extension

extension UTType {
    static let epub = UTType(filenameExtension: "epub") ?? .data
}
