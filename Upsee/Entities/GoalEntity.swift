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
    var kindRaw: String = GoalKind.savings.rawValue
    var priority: Int = 50
    var createdAt: Date
    var updatedAt: Date

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var kind: GoalKind {
        get { GoalKind(rawValue: kindRaw) ?? .savings }
        set { kindRaw = newValue.rawValue }
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

enum GoalKind: String, Codable, CaseIterable {
    case savings
    case retirement
    case house
    case education
    case sabbatical
    case business
    case travel
    case emergency
    case other

    var displayName: String {
        switch self {
        case .savings: return "Savings"
        case .retirement: return "Retirement"
        case .house: return "House"
        case .education: return "Education"
        case .sabbatical: return "Sabbatical"
        case .business: return "Business"
        case .travel: return "Travel"
        case .emergency: return "Emergency Fund"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .savings: return "banknote"
        case .retirement: return "figure.walk"
        case .house: return "house"
        case .education: return "graduationcap"
        case .sabbatical: return "leaf"
        case .business: return "briefcase"
        case .travel: return "airplane"
        case .emergency: return "shield.lefthalf.filled"
        case .other: return "circle"
        }
    }

    var tint: Color {
        switch self {
        case .savings: return .blue
        case .retirement: return .purple
        case .house: return .brown
        case .education: return .indigo
        case .sabbatical: return .green
        case .business: return .orange
        case .travel: return .pink
        case .emergency: return .red
        case .other: return .secondary
        }
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
