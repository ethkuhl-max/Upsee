import Foundation
import SwiftData
import SwiftUI

/// A tax-advantaged retirement account. Distinct from `BalanceSheetItem` because
/// the contribution-limit and tax-treatment math matters separately from raw
/// asset value — Roth conversion planning, contribution headroom, asset location.
@Model
final class RetirementAccount {
    var name: String
    var kindRaw: String
    var currentBalance: Decimal
    var contributionsYTD: Decimal
    var employerMatchYTD: Decimal
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var kind: RetirementAccountKind {
        get { RetirementAccountKind(rawValue: kindRaw) ?? .traditionalIRA }
        set { kindRaw = newValue.rawValue }
    }

    init(
        name: String,
        kind: RetirementAccountKind = .traditionalIRA,
        currentBalance: Decimal = 0,
        contributionsYTD: Decimal = 0,
        employerMatchYTD: Decimal = 0
    ) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.currentBalance = currentBalance
        self.contributionsYTD = contributionsYTD
        self.employerMatchYTD = employerMatchYTD
        self.note = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Contribution headroom remaining for the current calendar year.
    var headroom: Decimal {
        max(0, kind.annualLimit2026 - contributionsYTD)
    }

    var contributionProgress: Double {
        let limit = NSDecimalNumber(decimal: kind.annualLimit2026).doubleValue
        let ytd = NSDecimalNumber(decimal: contributionsYTD).doubleValue
        guard limit > 0 else { return 0 }
        return min(1.0, ytd / limit)
    }
}

enum RetirementAccountKind: String, Codable, CaseIterable {
    case traditionalIRA
    case rothIRA
    case traditional401k
    case roth401k
    case sepIRA
    case solo401k
    case simpleIRA
    case hsa

    var displayName: String {
        switch self {
        case .traditionalIRA: return "Traditional IRA"
        case .rothIRA: return "Roth IRA"
        case .traditional401k: return "Traditional 401(k)"
        case .roth401k: return "Roth 401(k)"
        case .sepIRA: return "SEP-IRA"
        case .solo401k: return "Solo 401(k)"
        case .simpleIRA: return "SIMPLE IRA"
        case .hsa: return "HSA"
        }
    }

    /// 2026 contribution limits, single filer under 50. Rough — verify before tax planning.
    var annualLimit2026: Decimal {
        switch self {
        case .traditionalIRA, .rothIRA: return 7_000
        case .traditional401k, .roth401k: return 23_500
        case .sepIRA: return 70_000
        case .solo401k: return 70_000
        case .simpleIRA: return 16_500
        case .hsa: return 4_300
        }
    }

    var isPreTax: Bool {
        switch self {
        case .traditionalIRA, .traditional401k, .sepIRA, .solo401k, .simpleIRA, .hsa: return true
        case .rothIRA, .roth401k: return false
        }
    }

    var isAfterTax: Bool { !isPreTax }

    var tint: Color {
        if isPreTax { return .blue }
        return .purple
    }

    var taxTreatmentLabel: String {
        isPreTax ? "Pre-tax" : "After-tax (Roth)"
    }
}
