import Foundation

/// Standard amortization math. Returns annualized debt service for DSCR work.
enum LoanEngine {
    /// Monthly payment on a fully amortizing loan.
    /// Formula: p * (r * (1+r)^n) / ((1+r)^n - 1) where r is the monthly rate, n is months.
    static func monthlyPayment(_ terms: LoanTerms) -> Decimal {
        let principal = NSDecimalNumber(decimal: terms.principal).doubleValue
        guard principal > 0, terms.amortizationYears > 0 else { return 0 }

        let monthlyRate = terms.annualRate / 12.0
        let months = Double(terms.amortizationYears * 12)

        // Edge case: 0% interest reduces to principal / months.
        if monthlyRate == 0 {
            return Decimal(principal / months)
        }

        let factor = pow(1 + monthlyRate, months)
        let payment = principal * (monthlyRate * factor) / (factor - 1)
        return Decimal(payment)
    }

    static func annualDebtService(_ terms: LoanTerms) -> Decimal {
        monthlyPayment(terms) * 12
    }

    /// Combined annual debt service across all loans in a financing stack.
    static func annualDebtService(_ scenario: FinancingScenario) -> Decimal {
        scenario.loans.reduce(Decimal(0)) { $0 + annualDebtService($1) }
    }
}
