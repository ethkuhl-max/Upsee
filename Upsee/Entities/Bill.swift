import Foundation
import SwiftData
import SwiftUI

/// A known upcoming or recurring obligation — rent, utility, credit card minimum,
/// subscription, tax estimate, etc. Distinct from `Transaction` (which is posted
/// money movement) and `AppCost` (which is per-app burn). Bills surface in the
/// calendar before they hit.
@Model
final class Bill {
    var name: String
    var payee: String
    var amount: Decimal
    var nextDueDate: Date
    var cadenceRaw: String
    var categoryRaw: String
    var autopay: Bool
    var lastPaidAt: Date?
    var note: String
    var endedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var cadence: BillCadence {
        get { BillCadence(rawValue: cadenceRaw) ?? .monthly }
        set { cadenceRaw = newValue.rawValue }
    }

    var category: TxCategory {
        get { TxCategory(rawValue: categoryRaw) ?? .uncategorized }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String,
        payee: String = "",
        amount: Decimal,
        nextDueDate: Date,
        cadence: BillCadence = .monthly,
        category: TxCategory = .utilities,
        autopay: Bool = false
    ) {
        self.name = name
        self.payee = payee
        self.amount = amount
        self.nextDueDate = nextDueDate
        self.cadenceRaw = cadence.rawValue
        self.categoryRaw = category.rawValue
        self.autopay = autopay
        self.note = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isActive: Bool {
        if let endedAt, endedAt < Date() { return false }
        return true
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: nextDueDate).day ?? 0
    }

    var isOverdue: Bool {
        nextDueDate < Calendar.current.startOfDay(for: Date()) && lastPaidNeedsAdvance()
    }

    /// True when we haven't recorded a payment for the current period.
    private func lastPaidNeedsAdvance() -> Bool {
        guard let last = lastPaidAt else { return true }
        // If lastPaidAt is before this period's expected pay date, we owe.
        let expectedPriorPay = Calendar.current.date(byAdding: cadence.dateComponent, value: -1, to: nextDueDate) ?? nextDueDate
        return last < expectedPriorPay
    }

    /// Returns the monthly normalized burn for budget math.
    func monthlyEquivalent() -> Decimal {
        switch cadence {
        case .weekly: return amount * 4
        case .biweekly: return amount * 2
        case .monthly: return amount
        case .quarterly: return amount / 3
        case .semiannual: return amount / 6
        case .annual: return amount / 12
        case .oneTime: return 0
        }
    }

    /// Advances the next due date by one cadence step. Called after marking paid.
    func advance() {
        let next = Calendar.current.date(byAdding: cadence.dateComponent, value: 1, to: nextDueDate) ?? nextDueDate
        nextDueDate = next
        updatedAt = Date()
    }
}

enum BillCadence: String, Codable, CaseIterable {
    case weekly, biweekly, monthly, quarterly, semiannual, annual, oneTime

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiannual: return "Semi-annual"
        case .annual: return "Annual"
        case .oneTime: return "One-time"
        }
    }

    var dateComponent: Calendar.Component { .day }

    var advanceDays: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .quarterly: return 91
        case .semiannual: return 182
        case .annual: return 365
        case .oneTime: return 0
        }
    }
}
