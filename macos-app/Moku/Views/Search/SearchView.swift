import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SearchViewModel()
    @State private var showCatalogManager = false
    @State private var newCatalogTitle = ""
    @State private var newCatalogURL = "https://"
    @State private var catalogFormError: String?
    @State private var transientNotice: String?

    var body: some View {
        let queryBinding = Binding(
            get: { viewModel.query },
            set: { viewModel.updateQuery($0) }
        )
        let selectedCatalogBinding = Binding(
            get: { viewModel.selectedCatalog?.id ?? "" },
            set: { viewModel.selectCatalog($0) }
        )

        ZStack {
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .ignoresSafeArea()

            if viewModel.query.isEmpty {
                emptyPrompt
            } else if viewModel.isSearching {
                progressState("Searching catalog…")
            } else if let errorMessage = viewModel.errorMessage, viewModel.results.isEmpty {
                messageState(
                    icon: "exclamationmark.triangle",
                    title: "Couldn’t load books",
                    message: errorMessage
                )
            } else if viewModel.results.isEmpty {
                messageState(
                    icon: "text.magnifyingglass",
                    title: "No downloadable books",
                    message: "Try another search or switch catalogs."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let transientNotice {
                            noticeBanner(transientNotice)
                                .padding(.horizontal, 16)
                        }

                        ForEach(viewModel.results) { book in
                            searchResultRow(book)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Discover")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .tracking(-0.3)
                            .lineLimit(1)
                        Text("Download books straight into your library.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 16)

                    Button {
                        showCatalogManager = true
                    } label: {
                        Label("Manage Catalogs", systemImage: "books.vertical.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Catalog")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Picker("Catalog", selection: selectedCatalogBinding) {
                            ForEach(viewModel.catalogs) { catalog in
                                Text(catalog.title).tag(catalog.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.035))
                    )

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        TextField(
                            "Search \(viewModel.selectedCatalog?.title ?? "catalog")…",
                            text: queryBinding
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                        if !viewModel.query.isEmpty {
                            Button {
                                viewModel.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.04))
                    )

                    Spacer(minLength: 0)
                }

                if let errorMessage = viewModel.errorMessage, !viewModel.query.isEmpty, !viewModel.results.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                    .opacity(0.95)
            )
            .background(.ultraThinMaterial.opacity(0.5))
        }
        .task {
            if viewModel.catalogs.isEmpty {
                viewModel.loadCatalogs()
            }
        }
        .sheet(isPresented: $showCatalogManager) {
            catalogManagerSheet
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MokuTheme.violet.opacity(0.06))
                    .frame(width: 100, height: 100)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(MokuTheme.violet.opacity(0.4))
            }
            Text("Search \(viewModel.selectedCatalog?.title ?? "a catalog")")
                .font(.system(size: 20, weight: .bold, design: .serif))
            Text("Find downloadable books and add them straight to your library.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func progressState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func messageState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func noticeBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.03))
        )
    }

    private func searchResultRow(_ book: DiscoverCatalogBook) -> some View {
        let isDownloading = viewModel.downloadingBookIDs.contains(book.id)

        return HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: book.coverURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        MokuTheme.coverColor(for: book.title)
                        Image(systemName: "book.closed")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .frame(width: 54, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(MokuTheme.violet)

                HStack(spacing: 6) {
                    badge(book.catalogTitle)
                    badge(book.formatSummary)
                    if let year = book.yearLabel {
                        badge(year)
                    }
                }

                if let description = book.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if !book.subjects.isEmpty {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(book.subjects, id: \.self) { subject in
                            badge(subject)
                        }
                    }
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    Task {
                        do {
                            try await viewModel.download(book, modelContext: modelContext)
                            transientNotice = "\(book.title) was added to your library."
                        } catch {
                            transientNotice = nil
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 90)
                    } else if let acquisition = book.preferredAcquisition {
                        Text("Download \(acquisition.format.displayName)")
                            .frame(minWidth: 90)
                    } else {
                        Text("Download")
                            .frame(minWidth: 90)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MokuTheme.violet)
                .controlSize(.small)
                .disabled(isDownloading || book.preferredAcquisition == nil)

                if let externalURL = book.externalURL {
                    Link(destination: externalURL) {
                        Label("Open source", systemImage: "arrow.up.right.square")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? .white.opacity(0.04) : .black.opacity(0.025))
        )
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.75) : .black.opacity(0.65))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.05))
            )
    }

    private var catalogManagerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Catalogs")
                .font(.system(size: 20, weight: .bold, design: .serif))

            Text("Built-ins are ready to use. Add your own OPDS catalogs too.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.catalogs) { catalog in
                        HStack(spacing: 10) {
                            Image(systemName: catalog.isCustom ? "link.circle" : "sparkles")
                                .foregroundStyle(catalog.isCustom ? MokuTheme.violet : MokuTheme.coral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(catalog.title)
                                    .font(.system(size: 13, weight: .medium))
                                Text(catalog.url)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if catalog.isCustom {
                                Button("Remove") {
                                    Task {
                                        await viewModel.removeCatalog(catalog)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            } else {
                                Text("Built-in")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.03))
                        )
                    }
                }
            }
            .frame(maxHeight: 220)

            VStack(alignment: .leading, spacing: 10) {
                Text("Add Custom Catalog")
                    .font(.system(size: 13, weight: .semibold))

                TextField("Catalog name", text: $newCatalogTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("https://catalog.example.com/opds", text: $newCatalogURL)
                    .textFieldStyle(.roundedBorder)

                if let catalogFormError {
                    Text(catalogFormError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                }

                HStack {
                    Spacer()
                    Button("Close") {
                        catalogFormError = nil
                        showCatalogManager = false
                    }
                    .buttonStyle(.bordered)

                    Button("Add Catalog") {
                        catalogFormError = nil
                        Task {
                            do {
                                try await viewModel.addCustomCatalog(
                                    title: newCatalogTitle,
                                    url: newCatalogURL
                                )
                                newCatalogTitle = ""
                                newCatalogURL = "https://"
                                showCatalogManager = false
                            } catch {
                                catalogFormError = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MokuTheme.violet)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        content
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
