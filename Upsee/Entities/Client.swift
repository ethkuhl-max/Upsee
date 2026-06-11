import Foundation
import SwiftData
import SwiftUI

/// A balance-sheet line for a client (asset or liability). Conforms to `NetWorthLine`
/// so the existing `NetWorthEngine` works unchanged.
struct ClientLineItem: Codable, Equatable, Identifiable, NetWorthLine {
    var id: UUID
    var name: String
    var amount: Decimal
    var isAsset: Bool
    var category: String

    init(id: UUID = UUID(), name: String, amount: Decimal, isAsset: Bool, category: String = "") {
        self.id = id
        self.name = name
        self.amount = amount
        self.isAsset = isAsset
        self.category = category
    }
}

/// A logged client touchpoint (review, call, email).
struct ClientMeeting: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var summary: String

    init(id: UUID = UUID(), date: Date = Date(), summary: String) {
        self.id = id
        self.date = date
        self.summary = summary
    }
}

/// A funded goal for a client (e.g. retirement, college, home).
struct ClientGoal: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var targetDate: Date?

    init(id: UUID = UUID(), name: String, targetAmount: Decimal, currentAmount: Decimal = 0, targetDate: Date? = nil) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
    }

    var progress: Double {
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue
        let current = NSDecimalNumber(decimal: currentAmount).doubleValue
        guard target > 0 else { return 0 }
        return min(1, max(0, current / target))
    }

    /// Projected hit date given a monthly contribution; nil if already met or no funding.
    func projectedHitDate(monthlyContribution: Decimal) -> Date? {
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue
        let current = NSDecimalNumber(decimal: currentAmount).doubleValue
        let monthly = NSDecimalNumber(decimal: monthlyContribution).doubleValue
        guard current < target, monthly > 0 else { return nil }
        let months = Int((target - current) / monthly).advanced(by: 1)
        return Calendar.current.date(byAdding: .month, value: months, to: Date())
    }
}

enum ClientStatus: String, Codable, CaseIterable {
    case prospect, active, inactive

    var displayName: String {
        switch self {
        case .prospect: return "Prospect"
        case .active: return "Active"
        case .inactive: return "Inactive"
        }
    }

    var tint: Color {
        switch self {
        case .prospect: return .blue
        case .active: return .green
        case .inactive: return .gray
        }
    }
}

/// A client/household managed by the advisor. Financial detail is stored as Codable
/// blobs so a client is self-contained (no per-client schema sprawl).
@Model
final class Client {
    var name: String
    var email: String
    var householdNote: String
    var statusRaw: String

    var aum: Decimal                 // assets under management with this advisor
    var feePercent: Double           // annual advisory fee, as a fraction (0.01 = 1%)
    var riskScore: Int               // 0…100, from the questionnaire (0 = none yet)

    var monthlyIncome: Decimal
    var monthlyExpenses: Decimal

    var reviewCadenceMonths: Int
    var lastReviewDate: Date?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    private var lineItemsData: Data?
    private var meetingsData: Data?
    private var riskAnswersData: Data?
    private var goalsData: Data?

    var status: ClientStatus {
        get { ClientStatus(rawValue: statusRaw) ?? .prospect }
        set { statusRaw = newValue.rawValue }
    }

    var lineItems: [ClientLineItem] {
        get { decode([ClientLineItem].self, lineItemsData) ?? [] }
        set { lineItemsData = encode(newValue) }
    }

    var meetings: [ClientMeeting] {
        get { decode([ClientMeeting].self, meetingsData) ?? [] }
        set { meetingsData = encode(newValue) }
    }

    /// Questionnaire answers (one option index per question). Empty until profiled.
    var riskAnswers: [Int] {
        get { decode([Int].self, riskAnswersData) ?? [] }
        set { riskAnswersData = encode(newValue) }
    }

    var goals: [ClientGoal] {
        get { decode([ClientGoal].self, goalsData) ?? [] }
        set { goalsData = encode(newValue) }
    }

    var nextReviewDate: Date? {
        guard let last = lastReviewDate, reviewCadenceMonths > 0 else { return nil }
        return Calendar.current.date(byAdding: .month, value: reviewCadenceMonths, to: last)
    }

    var annualFeeRevenue: Decimal {
        aum * Decimal(feePercent)
    }

    init(
        name: String,
        email: String = "",
        status: ClientStatus = .prospect,
        aum: Decimal = 0,
        feePercent: Double = 0.01,
        reviewCadenceMonths: Int = 12
    ) {
        self.name = name
        self.email = email
        self.householdNote = ""
        self.statusRaw = status.rawValue
        self.aum = aum
        self.feePercent = feePercent
        self.riskScore = 0
        self.monthlyIncome = 0
        self.monthlyExpenses = 0
        self.reviewCadenceMonths = reviewCadenceMonths
        self.lastReviewDate = nil
        self.notes = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }
}
