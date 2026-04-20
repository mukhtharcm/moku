import SwiftUI

struct MokuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Import Book…") {
                NotificationCenter.default.post(
                    name: .importBook,
                    object: nil
                )
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let importBook = Notification.Name("importBook")
}
