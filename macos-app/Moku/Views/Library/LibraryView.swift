import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = LibraryViewModel()
    @State private var selectedBook: MokuBook?
    @State private var hoveredBook: String?
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .ignoresSafeArea()

            if viewModel.filteredBooks.isEmpty && viewModel.searchQuery.isEmpty {
                emptyState
            } else if viewModel.filteredBooks.isEmpty {
                noResults
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // "Continue Reading" hero
                        if !viewModel.currentlyReading.isEmpty && viewModel.searchQuery.isEmpty {
                            continueReadingSection
                        }

                        // Library header with count
                        libraryHeader

                        // Book grid / list
                        bookContent
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) { toolbar }
        .onAppear { viewModel.setup(modelContext: modelContext) }
        .onReceive(NotificationCenter.default.publisher(for: .triggerImport)) { _ in
            viewModel.importBook()
        }
        .onDrop(of: [.epub, .fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MokuTheme.coral, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                    .background(MokuTheme.coral.opacity(0.05))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            Text("Library")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .tracking(-0.3)

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search…", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(width: 150)
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.04))
            )

            // Sort
            Menu {
                ForEach(LibraryViewModel.SortMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(duration: 0.3)) { viewModel.sortMode = mode }
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if viewModel.sortMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)

            // View mode
            Picker("", selection: $viewModel.viewMode) {
                Image(systemName: "square.grid.2x2").tag(LibraryViewModel.ViewMode.grid)
                Image(systemName: "list.bullet").tag(LibraryViewModel.ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 72)

            // Import
            Button { viewModel.importBook() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .help("Import EPUB (⌘O)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .opacity(0.95)
        )
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Continue Reading

    private var continueReadingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Continue Reading")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.currentlyReading, id: \.id) { book in
                        ContinueReadingCard(
                            book: book,
                            isHovered: hoveredBook == "cr-\(book.id)",
                            onOpen: { openWindow(id: "reader", value: book.id) }
                        )
                        .onHover { hovering in
                            withAnimation(.easeOut(duration: 0.2)) {
                                hoveredBook = hovering ? "cr-\(book.id)" : nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Library Header

    private var libraryHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("All Books")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.secondary)

            Text("\(viewModel.filteredBooks.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MokuTheme.violet.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(MokuTheme.violet.opacity(0.1))
                )

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Book Content

    @ViewBuilder
    private var bookContent: some View {
        switch viewModel.viewMode {
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 180))],
                spacing: 24
            ) {
                ForEach(viewModel.filteredBooks, id: \.id) { book in
                    BookGridItem(
                        book: book,
                        isHovered: hoveredBook == book.id
                    )
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.2)) {
                            hoveredBook = hovering ? book.id : nil
                        }
                    }
                    .onTapGesture(count: 2) { openWindow(id: "reader", value: book.id) }
                    .onTapGesture(count: 1) { selectedBook = book }
                    .contextMenu { bookContextMenu(book) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

        case .list:
            LazyVStack(spacing: 2) {
                ForEach(viewModel.filteredBooks, id: \.id) { book in
                    BookListRow(
                        book: book,
                        isHovered: hoveredBook == book.id
                    )
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            hoveredBook = hovering ? book.id : nil
                        }
                    }
                    .onTapGesture(count: 2) { openWindow(id: "reader", value: book.id) }
                    .contextMenu { bookContextMenu(book) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func bookContextMenu(_ book: MokuBook) -> some View {
        Group {
            Button { openWindow(id: "reader", value: book.id) } label: {
                Label("Open", systemImage: "book")
            }
            Divider()
            Button(role: .destructive) { viewModel.deleteBook(book) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MokuTheme.coral.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "books.vertical")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(MokuTheme.coral.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text("Your Library Awaits")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .tracking(-0.3)
                Text("Import EPUB files to start reading")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Button { viewModel.importBook() } label: {
                Label("Import EPUB", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(MokuTheme.coral)
            .controlSize(.large)

            Text("or drag and drop files here")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No books match \"\(viewModel.searchQuery)\"")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Drop Handling

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

// MARK: - Continue Reading Card

struct ContinueReadingCard: View {
    let book: MokuBook
    let isHovered: Bool
    let onOpen: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                BookCoverView(coverPath: book.coverPath, title: book.title)
                    .frame(width: 56, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 1, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .lineLimit(2)
                    Text(book.author)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let progress = book.readingProgress {
                        HStack(spacing: 6) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.06))
                                    Capsule()
                                        .fill(MokuTheme.coral)
                                        .frame(width: geo.size.width * CGFloat(progress.overallProgress))
                                }
                            }
                            .frame(height: 4)

                            Text("\(Int(progress.overallProgress * 100))%")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(width: 140, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: MokuTheme.cornerRadiusMedium)
                    .fill(colorScheme == .dark ? MokuTheme.nightCard : MokuTheme.paperWhite)
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.04), radius: isHovered ? 8 : 4, y: isHovered ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
    }
}

// MARK: - Book Grid Item

struct BookGridItem: View {
    let book: MokuBook
    let isHovered: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                BookCoverView(coverPath: book.coverPath, title: book.title)
                    .frame(width: 130, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: MokuTheme.cornerRadiusSmall))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 4)
                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)

                // Progress badge
                if let progress = book.readingProgress, progress.overallProgress > 0 {
                    Text("\(Int(progress.overallProgress * 100))%")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(MokuTheme.violet.opacity(0.85))
                        )
                        .offset(x: -6, y: -6)
                }
            }

            VStack(spacing: 3) {
                Text(book.title)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(book.author)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 130)
        }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(duration: 0.25), value: isHovered)
    }
}

// MARK: - Book List Row

struct BookListRow: View {
    let book: MokuBook
    let isHovered: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            BookCoverView(coverPath: book.coverPath, title: book.title)
                .frame(width: 36, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .lineLimit(1)
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let progress = book.readingProgress, progress.overallProgress > 0 {
                HStack(spacing: 6) {
                    // Mini progress bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.05))
                            .frame(width: 48, height: 3)
                        Capsule()
                            .fill(MokuTheme.violet)
                            .frame(width: 48 * CGFloat(progress.overallProgress), height: 3)
                    }
                    Text("\(Int(progress.overallProgress * 100))%")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered
                    ? (colorScheme == .dark ? .white.opacity(0.04) : .black.opacity(0.03))
                    : .clear
                )
        )
    }
}

// MARK: - Book Cover View

struct BookCoverView: View {
    let coverPath: String?
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            if let coverPath,
               let coverURL = EpubService.coverURL(for: coverPath),
               let image = NSImage(contentsOf: coverURL) {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // Subtle spine highlight on left edge
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 5)
                        Spacer()
                    }
                }
            } else {
                // Generated placeholder cover
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [
                            MokuTheme.coverColor(for: title),
                            MokuTheme.coverColor(for: title).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Spine highlight
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 5)
                        Spacer()
                    }

                    // Title and accent
                    VStack(alignment: .leading, spacing: 6) {
                        Spacer()

                        // Accent bar
                        RoundedRectangle(cornerRadius: 1)
                            .fill(MokuTheme.coverAccentColor(for: title))
                            .frame(width: 20, height: 3)

                        Text(title)
                            .font(.system(size: max(9, geo.size.width * 0.08), weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(3)
                            .lineSpacing(1)
                    }
                    .padding(10)

                    // Faint book icon watermark
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: geo.size.width * 0.22))
                                .foregroundStyle(.white.opacity(0.04))
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - UTType extension

extension UTType {
    static let epub = UTType(filenameExtension: "epub") ?? .data
}
