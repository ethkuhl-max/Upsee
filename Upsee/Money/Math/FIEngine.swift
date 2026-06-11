import Foundation

struct FISummary {
    /// 25× annual expenses (standard FI rule, ~4% safe withdrawal).
    let fiNumber: Decimal
    /// Current liquid + invested + retirement balance.
    let currentNetWorth: Decimal
    /// % progress toward FI (0...1+).
    let progress: Double
    /// Years to reach FI at the current savings rate + assumed return.
    let yearsToFI: Double?
    /// Lean FI = 15× expenses, a stricter early-FI threshold.
    let leanFI: Decimal
    /// Fat FI = 33× expenses, a comfort cushion.
    let fatFI: Decimal
    /// Months of expenses your current net worth covers (runway, not FI).
    let coverageMonths: Double
}

enum FIEngine {
    /// `safeWithdrawalRate` = 0.04 is the canonical 25× multiplier.
    static func summarize(
        annualExpenses: Decimal,
        netWorth: Decimal,
        annualSavings: Decimal,
        assumedReturn: Double = 0.07,
        safeWithdrawalRate: Double = 0.04
    ) -> FISummary {
        let exp = NSDecimalNumber(decimal: annualExpenses).doubleValue
        let nw = NSDecimalNumber(decimal: netWorth).doubleValue
        let savings = NSDecimalNumber(decimal: annualSavings).doubleValue

        let fiTarget = exp / max(safeWithdrawalRate, 0.001)
        let progress = fiTarget > 0 ? nw / fiTarget : 0

        let years: Double? = {
            guard fiTarget > nw, savings > 0 else {
                return nw >= fiTarget ? 0 : nil
            }
            // Iterative compounding — solve for years where nw * (1+r)^y + savings * (((1+r)^y - 1)/r) >= target.
            var balance = nw
            for y in 1...100 {
                balance = balance * (1 + assumedReturn) + savings
                if balance >= fiTarget { return Double(y) }
            }
            return nil
        }()

        let coverageMonths: Double = exp > 0 ? (nw / exp) * 12 : 0

        return FISummary(
            fiNumber: Decimal(fiTarget),
            currentNetWorth: netWorth,
            progress: progress,
            yearsToFI: years,
            leanFI: Decimal(exp * 15),
            fatFI: Decimal(exp * 33),
            coverageMonths: coverageMonths
        )
    }
}
