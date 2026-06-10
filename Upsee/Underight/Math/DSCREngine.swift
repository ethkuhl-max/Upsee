import Foundation

/// DSCR = normalized SDE ÷ annual debt service.
/// SBA 7(a) underwriting typically requires ≥ 1.25; a lender's hard floor is 1.15.
enum DSCRReading: String, Codable, Equatable {
    case healthy        // ≥ 1.40
    case adequate       // 1.25 ≤ x < 1.40
    case marginal       // 1.15 ≤ x < 1.25
    case underwater     // < 1.15

    init(_ value: Double) {
        switch value {
        case 1.40...:        self = .healthy
        case 1.25..<1.40:    self = .adequate
        case 1.15..<1.25:    self = .marginal
        default:             self = .underwater
        }
    }

    var label: String {
        switch self {
        case .healthy:    return "Healthy"
        case .adequate:   return "Adequate"
        case .marginal:   return "Marginal — lender pushback likely"
        case .underwater: return "Underwater — does not pencil"
        }
    }
}

struct DSCRResult: Codable, Equatable {
    let value: Double
    let normalizedSDE: Decimal
    let annualDebtService: Decimal
    let reading: DSCRReading
}

enum DSCREngine {
    /// DSCR for a single loan against a normalized SDE.
    static func dscr(normalizedSDE: Decimal, loan: LoanTerms) -> DSCRResult {
        let debtService = LoanEngine.annualDebtService(loan)
        return dscr(normalizedSDE: normalizedSDE, annualDebtService: debtService)
    }

    /// DSCR for a complete financing scenario.
    static func dscr(normalizedSDE: Decimal, scenario: FinancingScenario) -> DSCRResult {
        let debtService = LoanEngine.annualDebtService(scenario)
        return dscr(normalizedSDE: normalizedSDE, annualDebtService: debtService)
    }

    private static func dscr(normalizedSDE: Decimal, annualDebtService: Decimal) -> DSCRResult {
        let sdeDouble = NSDecimalNumber(decimal: normalizedSDE).doubleValue
        let dsDouble = NSDecimalNumber(decimal: annualDebtService).doubleValue
        let value = dsDouble > 0 ? sdeDouble / dsDouble : .infinity
        return DSCRResult(
            value: value,
            normalizedSDE: normalizedSDE,
            annualDebtService: annualDebtService,
            reading: DSCRReading(value)
        )
    }

    /// Maximum purchase price at which the loan still meets the target DSCR.
    /// Assumes 100% of price is financed at the supplied rate and amortization.
    /// Callers should subtract any planned buyer equity / seller note separately.
    static func maxOfferAt(
        targetDSCR: Double,
        normalizedSDE: Decimal,
        rate: Double,
        amortizationYears: Int
    ) -> Decimal {
        let sdeDouble = NSDecimalNumber(decimal: normalizedSDE).doubleValue
        guard targetDSCR > 0, sdeDouble > 0, amortizationYears > 0 else { return 0 }

        let maxAnnualDebtService = sdeDouble / targetDSCR
        let maxMonthlyPayment = maxAnnualDebtService / 12.0

        let monthlyRate = rate / 12.0
        let months = Double(amortizationYears * 12)

        if monthlyRate == 0 {
            return Decimal(maxMonthlyPayment * months)
        }

        let factor = pow(1 + monthlyRate, months)
        let maxPrincipal = maxMonthlyPayment * (factor - 1) / (monthlyRate * factor)
        return Decimal(maxPrincipal)
    }
}
