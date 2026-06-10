import Foundation
import SwiftData

/// Singleton — one PersonalEntity per Upsee install. Aggregates personal CFO data
/// (income, expenses, savings, tax bracket) so the dashboard can render runway and
/// monthly burn without needing per-month entries in v1.
@Model
final class PersonalEntity {
    var monthlyIncome: Decimal
    var monthlyExpenses: Decimal
    var currentSavings: Decimal
    var taxBracketEstimate: Double
    var note: String
    var updatedAt: Date

    // Inputs for the advanced tax estimate.
    var filingStatusRaw: String = FilingStatus.single.rawValue
    var stateTaxRate: Double = 0
    /// Fraction of income that is self-employment earnings (drives SECA tax). 1.0 = fully 1099.
    var selfEmploymentPortion: Double = 0

    var filingStatus: FilingStatus {
        get { FilingStatus(rawValue: filingStatusRaw) ?? .single }
        set { filingStatusRaw = newValue.rawValue }
    }

    init(
        monthlyIncome: Decimal = 0,
        monthlyExpenses: Decimal = 0,
        currentSavings: Decimal = 0,
        taxBracketEstimate: Double = 0.24
    ) {
        self.monthlyIncome = monthlyIncome
        self.monthlyExpenses = monthlyExpenses
        self.currentSavings = currentSavings
        self.taxBracketEstimate = taxBracketEstimate
        self.note = ""
        self.updatedAt = Date()
        self.filingStatusRaw = FilingStatus.single.rawValue
        self.stateTaxRate = 0
        self.selfEmploymentPortion = 0
    }

    var monthlyBurn: Decimal {
        max(0, monthlyExpenses - monthlyIncome)
    }

    var runwayMonths: Double {
        let burn = NSDecimalNumber(decimal: monthlyBurn).doubleValue
        let savings = NSDecimalNumber(decimal: currentSavings).doubleValue
        guard burn > 0 else { return .infinity }
        return savings / burn
    }
}
