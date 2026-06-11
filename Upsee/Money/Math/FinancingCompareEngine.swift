import Foundation

struct FinancingOption: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var kind: FinancingKind
    /// Down payment / cash outlay at t=0.
    var downPayment: Decimal
    /// Loan APR (ignored for cash).
    var apr: Double
    /// Term in months (ignored for cash).
    var termMonths: Int
    /// Required residual/balloon at end (lease).
    var residual: Decimal
    /// Recurring monthly payment (lease) — overrides amortization if > 0.
    var fixedMonthlyPayment: Decimal
}

enum FinancingKind: String, CaseIterable {
    case cash
    case loan
    case lease

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .loan: return "Loan"
        case .lease: return "Lease"
        }
    }
}

struct FinancingComparison: Identifiable {
    let id = UUID()
    let option: FinancingOption
    /// Total monthly payment (or 0 for cash).
    let monthlyPayment: Decimal
    /// Sum of all payments over the term + down payment + residual paid.
    let totalCashOut: Decimal
    /// Interest paid (loan) or finance cost (lease, vs principal).
    let financeCost: Decimal
    /// Hypothetical opportunity cost: cash not deployed at `assumedReturn`
    /// would have compounded to this much.
    let opportunityCost: Decimal
    /// All-in cost = totalCashOut + opportunityCost.
    let trueCost: Decimal
    /// What you end up owning at the end (full for cash/loan, 0 for lease).
    let endingEquity: Decimal
}

/// Compares cash vs loan vs lease for a single purchase. Captures opportunity
/// cost (cash sitting > cash invested) explicitly so the "always pay cash"
/// reflex gets challenged with numbers.
enum FinancingCompareEngine {
    static func compare(
        purchasePrice: Decimal,
        options: [FinancingOption],
        assumedReturn: Double = 0.07,
        availableCash: Decimal
    ) -> [FinancingComparison] {
        options.map { build(option: $0, purchasePrice: purchasePrice, assumedReturn: assumedReturn, availableCash: availableCash) }
    }

    private static func build(
        option: FinancingOption,
        purchasePrice: Decimal,
        assumedReturn: Double,
        availableCash: Decimal
    ) -> FinancingComparison {
        let price = NSDecimalNumber(decimal: purchasePrice).doubleValue
        let down = NSDecimalNumber(decimal: option.downPayment).doubleValue
        let apr = option.apr
        let termMonths = max(1, option.termMonths)
        let fixedPay = NSDecimalNumber(decimal: option.fixedMonthlyPayment).doubleValue
        let residual = NSDecimalNumber(decimal: option.residual).doubleValue

        var monthlyPay = 0.0
        var totalCashOut = 0.0
        var financeCost = 0.0
        var endingEquity = price

        switch option.kind {
        case .cash:
            totalCashOut = price
            monthlyPay = 0
            financeCost = 0
            endingEquity = price
        case .loan:
            let financedPrincipal = max(0, price - down)
            let derivedPayment = NSDecimalNumber(decimal:
                LoanScheduleEngine.standardMonthlyPayment(
                    principal: Decimal(financedPrincipal),
                    apr: apr,
                    termMonths: termMonths
                )
            ).doubleValue
            monthlyPay = fixedPay > 0 ? fixedPay : derivedPayment
            let totalPayments = monthlyPay * Double(termMonths)
            totalCashOut = down + totalPayments
            financeCost = totalPayments - financedPrincipal
            endingEquity = price
        case .lease:
            monthlyPay = fixedPay
            totalCashOut = down + monthlyPay * Double(termMonths) + residual
            // Finance cost = total cash out − (resale-equivalent value at end).
            // For an open-ended buyout, assume the user pays residual to keep
            // it. If residual = 0, lease total is treated as pure expense.
            financeCost = totalCashOut - residual
            endingEquity = residual > 0 ? residual : 0
        }

        // Opportunity cost: cash not deployed earns market return over term.
        // Cash deployed = max(down, availableCash drag) compounded at assumedReturn.
        let cashUsedNow = down + (option.kind == .cash ? price - down : 0)
        let years = Double(termMonths) / 12.0
        let opportunity = cashUsedNow * (pow(1 + assumedReturn, years) - 1)

        let trueCost = totalCashOut + opportunity - (endingEquity * 0) // explicit no-credit for equity to keep apples-to-apples
        _ = availableCash // surfaced for future "stretches reserves" warning

        return FinancingComparison(
            option: option,
            monthlyPayment: Decimal(monthlyPay),
            totalCashOut: Decimal(totalCashOut),
            financeCost: Decimal(financeCost),
            opportunityCost: Decimal(opportunity),
            trueCost: Decimal(trueCost),
            endingEquity: Decimal(endingEquity)
        )
    }
}
