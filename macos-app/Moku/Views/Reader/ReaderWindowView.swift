import SwiftUI
import SwiftData

/// Wrapper that resolves a book ID into a MokuBook and presents the reader.
/// Used by the separate reader WindowGroup.
struct ReaderWindowView: View {
    let bookId: String
    @Environment(\.modelContext) private var modelContext
    @State private var book: MokuBook?
    @State private var loaded = false

    var body: some View {
        Group {
            if let book {
                ReaderView(book: book)
            } else if loaded {
                VStack(spacing: 14) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Book not found")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { resolveBook() }
    }

    private func resolveBook() {
        let id = bookId
        let descriptor = FetchDescriptor<MokuBook>(
            predicate: #Predicate { $0.id == id }
        )
        book = try? modelContext.fetch(descriptor).first
        loaded = true
    }
}
