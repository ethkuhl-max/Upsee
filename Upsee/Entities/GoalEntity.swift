import Foundation
import SwiftData
import SwiftUI

@Model
final class GoalEntity {
    var name: String
    var summary: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var targetDate: Date?
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        name: String,
        summary: String = "",
        targetAmount: Decimal = 0,
        currentAmount: Decimal = 0,
        targetDate: Date? = nil,
        status: GoalStatus = .active
    ) {
        self.name = name
        self.summary = summary
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var progress: Double {
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue
        let current = NSDecimalNumber(decimal: currentAmount).doubleValue
        guard target > 0 else { return 0 }
        return min(1.0, max(0.0, current / target))
    }

    var remaining: Decimal {
        max(0, targetAmount - currentAmount)
    }

    /// Projected hit date given a monthly savings rate. nil if monthly is zero or
    /// already achieved.
    func projectedHitDate(monthlySavings: Decimal) -> Date? {
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue
        let current = NSDecimalNumber(decimal: currentAmount).doubleValue
        let monthly = NSDecimalNumber(decimal: monthlySavings).doubleValue
        guard monthly > 0, current < target else { return nil }
        let monthsNeeded = ceil((target - current) / monthly)
        return Calendar.current.date(byAdding: .month, value: Int(monthsNeeded), to: Date())
    }
}

enum GoalStatus: String, Codable, CaseIterable {
    case active
    case paused
    case achieved
    case abandoned

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .achieved: return "Achieved"
        case .abandoned: return "Abandoned"
        }
    }

    var tint: Color {
        switch self {
        case .active: return .blue
        case .paused: return .orange
        case .achieved: return .green
        case .abandoned: return .gray
        }
    }
}
