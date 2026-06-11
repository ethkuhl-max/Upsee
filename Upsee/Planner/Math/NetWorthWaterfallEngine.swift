import Foundation

struct WaterfallStep: Identifiable {
    let id = UUID()
    let label: String
    let amount: Decimal
    let kind: WaterfallKind
}

enum WaterfallKind {
    case start, income, spending, contributions, marketReturn, end
}

struct NetWorthWaterfall {
    let startSnapshot: NetWorthSnapshot
    let endSnapshot: NetWorthSnapshot
    let startNetWorth: Decimal
    let endNetWorth: Decimal
    let delta: Decimal
    let steps: [WaterfallStep]
    /// Income + market gains as % of total positive contribution.
    let savedShare: Double
    let marketShare: Double
}

/// Decomposes the change in net worth between two snapshots into income,
/// spending, contributions, and a residual treated as market return.
/// Approximation: real planner attribution would track every account.
enum NetWorthWaterfallEngine {
    static func decompose(
        from start: NetWorthSnapshot,
        to end: NetWorthSnapshot,
        transactions: [Transaction]
    ) -> NetWorthWaterfall {
        let range = transactions.filter { $0.date >= start.date && $0.date <= end.date }
        let income = range.filter { $0.isInflow && $0.category == .income }.reduce(Decimal(0)) { $0 + $1.amount }
        let spending = range.filter { $0.isOutflow && $0.category != .transfer && $0.category != .investment && $0.category != .savings }
            .reduce(Decimal(0)) { $0 - $1.amount }
        let contributions = range.filter { $0.isOutflow && ($0.category == .investment || $0.category == .savings) }
            .reduce(Decimal(0)) { $0 - $1.amount }

        let netCashSaved = income - spending - contributions
        let totalKnownDelta = netCashSaved + contributions
        let actualDelta = end.netWorth - start.netWorth
        let marketReturn = actualDelta - totalKnownDelta

        let savedAbs = NSDecimalNumber(decimal: netCashSaved).doubleValue
        let marketAbs = NSDecimalNumber(decimal: marketReturn).doubleValue
        let totalAbs = max(0.01, abs(savedAbs) + abs(marketAbs))

        let steps: [WaterfallStep] = [
            WaterfallStep(label: "Start", amount: start.netWorth, kind: .start),
            WaterfallStep(label: "Income", amount: income, kind: .income),
            WaterfallStep(label: "Spending", amount: -spending, kind: .spending),
            WaterfallStep(label: "Contributions", amount: -contributions, kind: .contributions),
            WaterfallStep(label: "Market return", amount: marketReturn, kind: .marketReturn),
            WaterfallStep(label: "End", amount: end.netWorth, kind: .end),
        ]

        return NetWorthWaterfall(
            startSnapshot: start,
            endSnapshot: end,
            startNetWorth: start.netWorth,
            endNetWorth: end.netWorth,
            delta: actualDelta,
            steps: steps,
            savedShare: savedAbs / totalAbs,
            marketShare: marketAbs / totalAbs
        )
    }
}
