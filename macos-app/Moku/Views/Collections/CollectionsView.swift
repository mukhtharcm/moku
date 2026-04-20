import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \BookCollection.updatedAt, order: .reverse)
    private var collections: [BookCollection]
    @State private var showNewCollection = false
    @State private var newName = ""
    @State private var hoveredCollection: String?

    var body: some View {
        ZStack {
            (colorScheme == .dark ? MokuTheme.nightSurface : MokuTheme.warmCream)
                .ignoresSafeArea()

            if collections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 280))],
                        spacing: 16
                    ) {
                        ForEach(collections, id: \.id) { collection in
                            collectionCard(collection)
                        }

                        // Add new card
                        addCollectionCard
                    }
                    .padding(24)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text("Collections")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .tracking(-0.3)
                Spacer()
                if !collections.isEmpty {
                    Button { showNewCollection = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                    }
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
        .sheet(isPresented: $showNewCollection) { newCollectionSheet }
    }

    private func collectionCard(_ collection: BookCollection) -> some View {
        let isHovered = hoveredCollection == collection.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [collectionColor(collection.name), collectionColor(collection.name).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Spacer()
                Text("\(collection.books.count)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary))
            }

            Text(collection.name)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .lineLimit(2)

            Text(collection.books.isEmpty ? "No books yet" : "\(collection.books.count) books")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MokuTheme.cornerRadiusMedium)
                .fill(colorScheme == .dark ? MokuTheme.nightCard : MokuTheme.paperWhite)
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 6 : 3, y: isHovered ? 2 : 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { hovering in hoveredCollection = hovering ? collection.id : nil }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(collection)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var addCollectionCard: some View {
        Button { showNewCollection = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("New Collection")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: MokuTheme.cornerRadiusMedium)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(.quaternary)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MokuTheme.violet.opacity(0.06))
                    .frame(width: 100, height: 100)
                Image(systemName: "square.stack")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(MokuTheme.violet.opacity(0.5))
            }
            Text("No Collections Yet")
                .font(.system(size: 20, weight: .bold, design: .serif))
            Text("Organize your books into shelves")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button { showNewCollection = true } label: {
                Label("Create Collection", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(MokuTheme.violet)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var newCollectionSheet: some View {
        VStack(spacing: 20) {
            Text("New Collection")
                .font(.system(size: 16, weight: .bold, design: .serif))

            TextField("Collection name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            HStack(spacing: 12) {
                Button("Cancel") { showNewCollection = false; newName = "" }
                    .buttonStyle(.bordered)
                Button("Create") {
                    let collection = BookCollection(name: newName.trimmingCharacters(in: .whitespaces))
                    modelContext.insert(collection)
                    try? modelContext.save()
                    newName = ""
                    showNewCollection = false
                }
                .buttonStyle(.borderedProminent)
                .tint(MokuTheme.violet)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 340)
    }

    private func collectionColor(_ name: String) -> Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.65)
    }
}
