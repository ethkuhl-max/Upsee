import Foundation
import SwiftData
import SwiftUI

/// Distinct from `GoalEntity` (personal savings goal). App-scoped, with arbitrary
/// units — "100 CFIs", "$500 MRR", "App Store featured" — so the UI is flexible.
@Model
final class AppGoal {
    var title: String
    var statusRaw: String
    var targetValue: Double?
    var currentValue: Double?
    var unit: String
    var targetDate: Date?
    var createdAt: Date
    var updatedAt: Date

    var app: AppEntity?

    var status: AppGoalStatus {
        get { AppGoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        title: String,
        targetValue: Double? = nil,
        currentValue: Double? = nil,
        unit: String = "",
        targetDate: Date? = nil,
        status: AppGoalStatus = .active
    ) {
        self.title = title
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.targetDate = targetDate
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var progress: Double? {
        guard let target = targetValue, target > 0, let current = currentValue else { return nil }
        return min(1.0, max(0.0, current / target))
    }

    var quantifiableSummary: String? {
        guard let target = targetValue else { return nil }
        let current = currentValue ?? 0
        if unit.isEmpty {
            return "\(format(current)) / \(format(target))"
        }
        return "\(format(current)) / \(format(target)) \(unit)"
    }

    private func format(_ d: Double) -> String {
        if d == d.rounded() {
            return String(Int(d))
        }
        return String(format: "%.1f", d)
    }
}

enum AppGoalStatus: String, Codable, CaseIterable {
    case active
    case achieved
    case missed
    case paused
    case abandoned

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .achieved: return "Achieved"
        case .missed: return "Missed"
        case .paused: return "Paused"
        case .abandoned: return "Abandoned"
        }
    }

    var tint: Color {
        switch self {
        case .active: return .blue
        case .achieved: return .green
        case .missed: return .red
        case .paused: return .orange
        case .abandoned: return .gray
        }
    }
}
