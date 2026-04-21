import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    let collection: BookCollection
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @State private var showAddBooks = false
    @State private var hoveredBook: String?
    @State private var showDeleteCollectionAlert = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .ignoresSafeArea()

            if collection.books.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        bookGrid
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) { toolbar }
        .sheet(isPresented: $showAddBooks) { AddBooksSheet(collection: collection) }
        .alert("Delete Shelf?", isPresented: $showDeleteCollectionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(collection)
                try? modelContext.save()
            }
        } message: {
            Text("This will permanently delete the shelf \"\(collection.name)\". Books won't be deleted from your library.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            Text(collection.name)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .tracking(-0.3)
                .lineLimit(1)

            Text("\(collection.books.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MokuTheme.violet.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(MokuTheme.violet.opacity(0.1)))

            Spacer()

            Button { showAddBooks = true } label: {
                Label("Add Books", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                Button(role: .destructive) { showDeleteCollectionAlert = true } label: {
                    Label("Delete Shelf", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .opacity(0.95)
        )
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let desc = collection.collectionDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Book Grid

    private var bookGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150, maximum: 180))],
            spacing: 24
        ) {
            ForEach(collection.books, id: \.id) { book in
                VStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        BookCoverView(coverPath: book.coverPath, title: book.title)
                            .frame(width: 130, height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: MokuTheme.cornerRadiusSmall))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 4)

                        if let progress = book.readingProgress, progress.overallProgress > 0 {
                            Text("\(Int(progress.overallProgress * 100))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(MokuTheme.violet.opacity(0.85)))
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
                .scaleEffect(hoveredBook == book.id ? 1.04 : 1.0)
                .animation(.spring(duration: 0.25), value: hoveredBook == book.id)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.2)) {
                        hoveredBook = hovering ? book.id : nil
                    }
                }
                .onTapGesture(count: 2) { openWindow(id: "reader", value: book.id) }
                .onTapGesture(count: 1) { openWindow(id: "reader", value: book.id) }
                .contextMenu { bookContextMenu(book) }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private func bookContextMenu(_ book: MokuBook) -> some View {
        Group {
            Button { openWindow(id: "reader", value: book.id) } label: {
                Label("Open", systemImage: "book")
            }
            Divider()
            Button(role: .destructive) { removeBook(book) } label: {
                Label("Remove from Shelf", systemImage: "minus.circle")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MokuTheme.violet.opacity(0.06))
                    .frame(width: 100, height: 100)
                Image(systemName: "books.vertical")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(MokuTheme.violet.opacity(0.5))
            }

            VStack(spacing: 6) {
                Text("No Books Yet")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Text("Add books to this shelf to organize your library")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button { showAddBooks = true } label: {
                Label("Add Books", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(MokuTheme.violet)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func removeBook(_ book: MokuBook) {
        collection.books.removeAll { $0.id == book.id }
        try? modelContext.save()
    }
}

// MARK: - Add Books Sheet

struct AddBooksSheet: View {
    let collection: BookCollection
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var selectedIDs: Set<String> = []

    @Query(sort: \MokuBook.title) private var allBooks: [MokuBook]

    private var collectionBookIDs: Set<String> {
        Set(collection.books.map(\.id))
    }

    private var availableBooks: [MokuBook] {
        let notInCollection = allBooks.filter { book in
            !collectionBookIDs.contains(book.id)
        }
        if searchQuery.isEmpty { return notInCollection }
        let query = searchQuery.lowercased()
        return notInCollection.filter {
            $0.title.lowercased().contains(query) ||
            $0.author.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Books to \"\(collection.name)\"")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                    Text("\(availableBooks.count) books available")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !selectedIDs.isEmpty {
                    Button("Add \(selectedIDs.count) Book\(selectedIDs.count == 1 ? "" : "s")") {
                        addSelectedBooks()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MokuTheme.violet)
                    .controlSize(.small)
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search books…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.04))
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Book list
            if availableBooks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.green.opacity(0.6))
                    Text("All your books are already in this shelf")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(availableBooks, id: \.id) { book in
                            bookRow(book)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 480, height: 520)
        .background(colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
    }

    private func bookRow(_ book: MokuBook) -> some View {
        let isSelected = selectedIDs.contains(book.id)
        return HStack(spacing: 12) {
            BookCoverView(coverPath: book.coverPath, title: book.title)
                .frame(width: 36, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 4))

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

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MokuTheme.violet)
                    .font(.system(size: 16))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                    ? MokuTheme.violet.opacity(colorScheme == .dark ? 0.15 : 0.08)
                    : (colorScheme == .dark ? .white.opacity(0.02) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedIDs.remove(book.id)
            } else {
                selectedIDs.insert(book.id)
            }
        }
    }

    private func addSelectedBooks() {
        let booksToAdd = allBooks.filter { selectedIDs.contains($0.id) }
        for book in booksToAdd {
            if !collection.books.contains(where: { $0.id == book.id }) {
                collection.books.append(book)
            }
        }
        try? modelContext.save()
        dismiss()
    }
}