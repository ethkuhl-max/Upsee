import Foundation
import SwiftData

/// Stable per-day key (yyyy-MM-dd) so wellbeing and habits dedupe by calendar day.
enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
}

/// A daily founder wellbeing check-in. One per calendar day (keyed by `dayKey`).
@Model
final class WellbeingEntry {
    var dayKey: String
    var date: Date
    var energy: Int          // 1 (drained) … 5 (energized)
    var stress: Int          // 1 (calm) … 5 (overwhelmed)
    var sleepHours: Double
    var exerciseMinutes: Int
    var note: String
    var createdAt: Date

    init(
        date: Date = Date(),
        energy: Int = 3,
        stress: Int = 3,
        sleepHours: Double = 7.5,
        exerciseMinutes: Int = 0,
        note: String = ""
    ) {
        self.dayKey = DayKey.string(from: date)
        self.date = date
        self.energy = energy
        self.stress = stress
        self.sleepHours = sleepHours
        self.exerciseMinutes = exerciseMinutes
        self.note = note
        self.createdAt = Date()
    }
}
