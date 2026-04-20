import SwiftUI

// MARK: - Reader Action Protocol

/// Actions that the active reader window exposes to menu commands via FocusedValue.
@MainActor
protocol ReaderActions {
    func toggleBookmark()
    func showAnnotations()
    func toggleZenMode()
    func increaseFontSize()
    func decreaseFontSize()
    func nextChapter()
    func previousChapter()
}

// MARK: - FocusedValue Key

struct ReaderActionsKey: FocusedValueKey {
    typealias Value = ReaderActions
}

extension FocusedValues {
    var readerActions: ReaderActions? {
        get { self[ReaderActionsKey.self] }
        set { self[ReaderActionsKey.self] = newValue }
    }
}

// MARK: - Commands

struct MokuCommands: Commands {
    @FocusedValue(\.readerActions) private var readerActions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Import Book…") {
                NotificationCenter.default.post(name: .importBook, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("Reader") {
            Button("Toggle Bookmark") {
                readerActions?.toggleBookmark()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(readerActions == nil)

            Button("Annotations") {
                readerActions?.showAnnotations()
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(readerActions == nil)

            Divider()

            Button("Zen Mode") {
                readerActions?.toggleZenMode()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(readerActions == nil)

            Divider()

            Button("Increase Font Size") {
                readerActions?.increaseFontSize()
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(readerActions == nil)

            Button("Decrease Font Size") {
                readerActions?.decreaseFontSize()
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(readerActions == nil)

            Divider()

            Button("Next Chapter") {
                readerActions?.nextChapter()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(readerActions == nil)

            Button("Previous Chapter") {
                readerActions?.previousChapter()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(readerActions == nil)
        }
    }
}

extension Notification.Name {
    static let importBook = Notification.Name("importBook")
}
