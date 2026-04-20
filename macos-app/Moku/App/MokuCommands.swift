import SwiftUI

struct MokuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Import EPUB…") {
                NotificationCenter.default.post(
                    name: .importEPUB,
                    object: nil
                )
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let importEPUB = Notification.Name("importEPUB")
}
