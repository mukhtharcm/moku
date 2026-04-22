import Foundation
import SwiftData

@MainActor
@Observable
final class StatsViewModel {
    var sessions: [ReadingSession] = []
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalMinutes: Int = 0
    var booksReadThisYear: Int = 0
    var dailyMinutes: [Date: Int] = [:]
    var recentSessions: [ReadingSession] = []
    var isLoading = true

    func load(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ReadingSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        sessions = (try? modelContext.fetch(descriptor)) ?? []
        compute()
        isLoading = false
    }

    private func compute() {
        totalMinutes = sessions.reduce(0) { $0 + $1.durationSeconds } / 60

        let calendar = Calendar.current
        var byDay: [Date: Int] = [:]
        for s in sessions {
            let day = calendar.startOfDay(for: s.startedAt)
            byDay[day, default: 0] += s.durationSeconds / 60
        }
        dailyMinutes = byDay

        let (current, longest) = computeStreaks(byDay: byDay, calendar: calendar)
        currentStreak = current
        longestStreak = longest

        // Count books with ≥10 minutes of reading this year (meaningful engagement)
        let year = Calendar.current.component(.year, from: Date())
        var minutesByBook: [String: Int] = [:]
        for s in sessions where Calendar.current.component(.year, from: s.startedAt) == year {
            let key = s.book?.id ?? s.bookTitle
            minutesByBook[key, default: 0] += s.durationSeconds / 60
        }
        booksReadThisYear = minutesByBook.values.filter { $0 >= 10 }.count

        recentSessions = Array(sessions.prefix(20))
    }

    /// Computes current and longest reading streaks from a day→minutes map.
    /// Days are sorted descending. The current streak is only non-zero if the
    /// most recent reading day is today or yesterday (streak still active).
    private func computeStreaks(byDay: [Date: Int], calendar: Calendar) -> (current: Int, longest: Int) {
        let today = calendar.startOfDay(for: Date())
        let days = byDay.keys.sorted(by: >)  // most recent first
        guard !days.isEmpty else { return (0, 0) }

        let daysSinceMostRecent = calendar.dateComponents([.day], from: days[0], to: today).day ?? Int.max

        // Track the leading consecutive run (from the most recent day backwards)
        // and the overall longest run found anywhere.
        var leadingRun = 1   // consecutive days starting at days[0]
        var leadingEnded = false
        var run = 1          // current window run for longest computation
        var longest = 0

        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i], to: days[i - 1]).day ?? 0
            if diff == 1 {
                run += 1
                if !leadingEnded { leadingRun += 1 }
            } else {
                longest = max(longest, run)
                leadingEnded = true
                run = 1
            }
        }
        longest = max(longest, run)

        let current = daysSinceMostRecent <= 1 ? leadingRun : 0
        return (current, longest)
    }
}
