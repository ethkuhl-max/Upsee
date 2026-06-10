import Foundation

enum FilingStatus: String, Codable, CaseIterable {
    case single
    case marriedJoint

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .marriedJoint: return "Married, joint"
        }
    }
}

/// A full federal + self-employment + state estimate, with marginal and effective rates.
struct TaxBreakdown: Equatable {
    let grossIncome: Decimal
    let selfEmploymentIncome: Decimal
    let standardDeduction: Decimal
    let taxableIncome: Decimal
    let federalTax: Decimal
    let selfEmploymentTax: Decimal
    let stateTax: Decimal
    let totalTax: Decimal
    let effectiveRate: Double      // total tax ÷ gross income
    let marginalRate: Double       // top federal bracket reached
    let afterTaxIncome: Decimal
    let quarterlyPayment: Decimal
    let nextDueDate: Date?
}

/// Marginal federal income tax with self-employment (SECA) tax, the standard deduction,
/// and an optional flat state rate. Brackets are 2025 figures. Planning estimate, not advice.
enum IncomeTaxEngine {
    /// 2025 Social Security wage base for the 12.4% OASDI portion of SE tax.
    static let socialSecurityWageBase = 176_100.0
    static let seNetEarningsFactor = 0.9235   // SE income is taxed on 92.35%

    static func brackets(_ status: FilingStatus) -> [(lowerBound: Double, rate: Double)] {
        switch status {
        case .single:
            return [
                (0, 0.10), (11_925, 0.12), (48_475, 0.22), (103_350, 0.24),
                (197_300, 0.32), (250_525, 0.35), (626_350, 0.37),
            ]
        case .marriedJoint:
            return [
                (0, 0.10), (23_850, 0.12), (96_950, 0.22), (206_700, 0.24),
                (394_600, 0.32), (501_050, 0.35), (751_600, 0.37),
            ]
        }
    }

    static func standardDeduction(_ status: FilingStatus) -> Double {
        switch status {
        case .single: return 15_000
        case .marriedJoint: return 30_000
        }
    }

    static func calculate(
        grossIncome: Decimal,
        selfEmploymentIncome: Decimal,
        filingStatus: FilingStatus,
        stateRate: Double,
        now: Date = Date()
    ) -> TaxBreakdown {
        let gross = dbl(grossIncome)
        let seIncome = max(0, dbl(selfEmploymentIncome))

        // Self-employment (SECA) tax.
        let netSE = seIncome * seNetEarningsFactor
        let ssTax = min(netSE, socialSecurityWageBase) * 0.124
        let medicareTax = netSE * 0.029
        let seTax = netSE > 0 ? ssTax + medicareTax : 0
        let halfSEDeduction = seTax / 2.0

        // Federal taxable income after the half-SE deduction and standard deduction.
        let deduction = standardDeduction(filingStatus)
        let taxable = max(0, gross - halfSEDeduction - deduction)
        let federal = federalTax(taxable: taxable, status: filingStatus)
        let state = max(0, taxable) * max(0, stateRate)

        let total = federal.tax + seTax + state
        let effective = gross > 0 ? total / gross : 0

        return TaxBreakdown(
            grossIncome: grossIncome,
            selfEmploymentIncome: Decimal(seIncome),
            standardDeduction: Decimal(deduction),
            taxableIncome: Decimal(taxable),
            federalTax: Decimal(federal.tax),
            selfEmploymentTax: Decimal(seTax),
            stateTax: Decimal(state),
            totalTax: Decimal(total),
            effectiveRate: effective,
            marginalRate: federal.marginal,
            afterTaxIncome: Decimal(gross - total),
            quarterlyPayment: Decimal(total / 4.0),
            nextDueDate: TaxEstimator.nextQuarterlyDueDate(from: now)
        )
    }

    /// Stacks tax through each marginal bracket; returns total tax and the top rate reached.
    static func federalTax(taxable: Double, status: FilingStatus) -> (tax: Double, marginal: Double) {
        guard taxable > 0 else { return (0, 0) }
        let b = brackets(status)
        var tax = 0.0
        var marginal = b.first?.rate ?? 0
        for i in 0..<b.count {
            let lower = b[i].lowerBound
            guard taxable > lower else { break }
            let upper = i + 1 < b.count ? b[i + 1].lowerBound : .infinity
            let amountInBracket = min(taxable, upper) - lower
            tax += amountInBracket * b[i].rate
            marginal = b[i].rate
        }
        return (tax, marginal)
    }
}

private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
