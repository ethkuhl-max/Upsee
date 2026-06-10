import Foundation

/// Loan terms used to compute debt service and DSCR.
/// Defaults reflect typical SBA 7(a) acquisition financing as of 2026.
struct LoanTerms: Codable, Equatable {
    var principal: Decimal
    var annualRate: Double
    var amortizationYears: Int

    static let sbaDefault = LoanTerms(
        principal: 0,
        annualRate: 0.115,
        amortizationYears: 10
    )

    static let sbaConservative = LoanTerms(
        principal: 0,
        annualRate: 0.125,
        amortizationYears: 10
    )

    static let sellerNote = LoanTerms(
        principal: 0,
        annualRate: 0.07,
        amortizationYears: 5
    )
}

/// A complete financing scenario — typically SBA + seller note + buyer equity.
/// Combined annual debt service drives DSCR.
struct FinancingScenario: Codable, Equatable {
    var label: String
    var loans: [LoanTerms]
    var buyerEquity: Decimal
}
