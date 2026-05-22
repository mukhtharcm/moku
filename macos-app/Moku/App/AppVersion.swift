import Foundation

enum AppVersion {
    static var displayString: String {
        format(
            shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    static func format(shortVersion: String?, buildNumber: String?) -> String {
        let version = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let build = buildNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !version.isEmpty else {
            return "Version unavailable"
        }

        guard !build.isEmpty else {
            return "Version \(version)"
        }

        return "Version \(version) (\(build))"
    }
}
