import Foundation

/// Sync configuration keys and helpers.
/// The actual sync logic lives in PocketBaseClient + SyncEngine + SyncViewModel.
enum SyncService {
    static let serverURLKey = "syncServerURL"
    static let enabledKey = "syncEnabled"
    static let lastSyncAtKey = "syncLastSyncAt"

    static var lastSyncAt: Date? {
        get {
            let ms = UserDefaults.standard.integer(forKey: lastSyncAtKey)
            return ms > 0 ? Date(timeIntervalSince1970: Double(ms) / 1000.0) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(Int(date.timeIntervalSince1970 * 1000), forKey: lastSyncAtKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastSyncAtKey)
            }
        }
    }
}
