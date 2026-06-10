import Foundation

struct HabitStreak: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let completionRate30: Double   // fraction of the last 30 days completed
    let doneToday: Bool
}

/// Streak math over a set of completed day-keys (yyyy-MM-dd).
enum HabitStreakEngine {
    static func compute(completedDayKeys keys: Set<String>, today: Date = Date()) -> HabitStreak {
        let cal = Calendar(identifier: .gregorian)
        let todayKey = DayKey.string(from: today)
        let doneToday = keys.contains(todayKey)

        // Current streak: walk backwards from today (or yesterday if today isn't done yet).
        var current = 0
        var cursor = today
        if !doneToday { cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        while keys.contains(DayKey.string(from: cursor)) {
            current += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        // Longest streak across all completed days.
        let sortedDates = keys.compactMap { dayKeyToDate($0) }.sorted()
        var longest = 0
        var run = 0
        var previous: Date?
        for date in sortedDates {
            if let prev = previous, let next = cal.date(byAdding: .day, value: 1, to: prev),
               cal.isDate(next, inSameDayAs: date) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = date
        }

        // 30-day completion rate.
        var hits = 0
        for offset in 0..<30 {
            if let day = cal.date(byAdding: .day, value: -offset, to: today),
               keys.contains(DayKey.string(from: day)) {
                hits += 1
            }
        }
        let rate = Double(hits) / 30.0

        return HabitStreak(currentStreak: current, longestStreak: longest, completionRate30: rate, doneToday: doneToday)
    }

    private static let parseFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayKeyToDate(_ key: String) -> Date? {
        parseFormatter.date(from: key)
    }
}
