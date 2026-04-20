import Foundation

struct OnboardingManager {
    private static let key = "onboarding_completed"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
