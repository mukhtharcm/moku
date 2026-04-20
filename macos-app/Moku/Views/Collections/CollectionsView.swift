import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookCollection.updatedAt, order: .reverse)
    private var collections: [BookCollection]
    @State private var showNewCollection = false
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Collections")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Spacer()
                Button { showNewCollection = true } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            if collections.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No Collections Yet")
                        .font(.headline)
                    Text("Create shelves to organize your books")
                        .foregroundStyle(.secondary)
                    Button("Create Collection") { showNewCollection = true }
                        .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(collections, id: \.id) { collection in
                        HStack {
                            Image(systemName: "square.stack.fill")
                                .foregroundStyle(collectionColor(collection.name))
                            VStack(alignment: .leading) {
                                Text(collection.name)
                                    .font(.body)
                                Text("\(collection.books.count) books")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                modelContext.delete(collection)
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewCollection) {
            VStack(spacing: 16) {
                Text("New Collection")
                    .font(.headline)
                TextField("Collection name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                HStack {
                    Button("Cancel") { showNewCollection = false; newName = "" }
                        .buttonStyle(.bordered)
                    Button("Create") {
                        let collection = BookCollection(name: newName)
                        modelContext.insert(collection)
                        try? modelContext.save()
                        newName = ""
                        showNewCollection = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 320)
        }
    }

    private func collectionColor(_ name: String) -> Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.7)
    }
}
