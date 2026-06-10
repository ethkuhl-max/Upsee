import Foundation
import SwiftData
import SwiftUI

/// A logged estimated-tax payment. Pair with `TaxEstimator.estimate(...)` to track
/// paid vs owed per quarter, surface underpayment-penalty risk, and project end-of-year
/// balance owed.
@Model
final class TaxPayment {
    var paidAt: Date
    var amount: Decimal
    /// 1-4 where 4 is the January (next-year) due date.
    var quarterNumber: Int
    var taxYear: Int
    var kindRaw: String
    var note: String
    var createdAt: Date

    var kind: TaxPaymentKind {
        get { TaxPaymentKind(rawValue: kindRaw) ?? .federal }
        set { kindRaw = newValue.rawValue }
    }

    init(
        paidAt: Date = Date(),
        amount: Decimal = 0,
        quarterNumber: Int = 1,
        taxYear: Int = Calendar.current.component(.year, from: Date()),
        kind: TaxPaymentKind = .federal,
        note: String = ""
    ) {
        self.paidAt = paidAt
        self.amount = amount
        self.quarterNumber = max(1, min(4, quarterNumber))
        self.taxYear = taxYear
        self.kindRaw = kind.rawValue
        self.note = note
        self.createdAt = Date()
    }
}

enum TaxPaymentKind: String, Codable, CaseIterable {
    case federal
    case state
    case selfEmployment

    var displayName: String {
        switch self {
        case .federal: return "Federal"
        case .state: return "State"
        case .selfEmployment: return "Self-Employment"
        }
    }

    var tint: Color {
        switch self {
        case .federal: return .blue
        case .state: return .green
        case .selfEmployment: return .orange
        }
    }
}
