import Foundation
import SwiftData
import SwiftUI

/// A weekly commitment for a specific app — "this week's focus" + target hours.
/// Outcome is filled in at end of week. Actual hours are computed from TimeEntries.
@Model
final class WeeklyCommitment {
    var weekStart: Date
    var entityKind: String
    var entityLabel: String
    var commitment: String
    var hoursTarget: Int
    var outcome: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    var status: WeeklyCommitmentStatus {
        get { WeeklyCommitmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        weekStart: Date,
        entityKind: String,
        entityLabel: String,
        commitment: String,
        hoursTarget: Int = 0,
        status: WeeklyCommitmentStatus = .pending
    ) {
        self.weekStart = weekStart
        self.entityKind = entityKind
        self.entityLabel = entityLabel
        self.commitment = commitment
        self.hoursTarget = hoursTarget
        self.outcome = ""
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    var isCurrentWeek: Bool {
        let cal = Calendar.current
        let now = Date()
        return now >= weekStart && now < weekEnd
    }
}

enum WeeklyCommitmentStatus: String, Codable, CaseIterable {
    case pending
    case inProgress
    case hit
    case missed
    case dropped

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .hit: return "Hit"
        case .missed: return "Missed"
        case .dropped: return "Dropped"
        }
    }

    var tint: Color {
        switch self {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .hit: return .green
        case .missed: return .red
        case .dropped: return .gray
        }
    }
}

/// Helper for finding the Monday of a date's week (Gregorian, ISO style).
enum WeekStart {
    static func of(_ date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}
