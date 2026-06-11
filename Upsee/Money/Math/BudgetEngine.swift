import Foundation

struct BudgetLine: Identifiable {
    let id = UUID()
    let category: TxCategory
    let target: Decimal
    let actual: Decimal
    let remaining: Decimal     // target - actual; negative if over
    let utilization: Double    // 0...1+
    let status: BudgetStatus
}

enum BudgetStatus {
    case onTrack          // < 80% utilization
    case approaching      // 80-100%
    case over             // > 100%
    case underNoBudget    // spending in category but no budget set
}

struct BudgetSummary {
    let lines: [BudgetLine]
    let totalTarget: Decimal
    let totalActual: Decimal
    let overCategories: [BudgetLine]
    let underNoBudget: [BudgetLine]
}

enum BudgetEngine {
    static func summarize(
        budgets: [Budget],
        transactions: [Transaction],
        month: Date = Date()
    ) -> BudgetSummary {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        let monthStart = cal.date(from: comps) ?? month
        guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else {
            return BudgetSummary(lines: [], totalTarget: 0, totalActual: 0, overCategories: [], underNoBudget: [])
        }

        let monthTxs = transactions.filter { $0.date >= monthStart && $0.date < monthEnd }
        let outflowByCategory: [TxCategory: Decimal] = Dictionary(grouping: monthTxs.filter { $0.isOutflow }, by: { $0.category })
            .mapValues { txs in txs.reduce(Decimal(0)) { $0 - $1.amount } }

        var lines: [BudgetLine] = []

        // Existing budgets first.
        for budget in budgets {
            let actual = outflowByCategory[budget.category] ?? 0
            let remaining = budget.monthlyTarget - actual
            let utilization: Double = {
                let t = NSDecimalNumber(decimal: budget.monthlyTarget).doubleValue
                guard t > 0 else { return 0 }
                return NSDecimalNumber(decimal: actual).doubleValue / t
            }()
            let status: BudgetStatus = {
                if utilization > 1.0 { return .over }
                if utilization > 0.8 { return .approaching }
                return .onTrack
            }()
            lines.append(.init(
                category: budget.category,
                target: budget.monthlyTarget,
                actual: actual,
                remaining: remaining,
                utilization: utilization,
                status: status
            ))
        }

        // Categories with spending but no budget — surface to prompt setting one.
        let budgetedSet = Set(budgets.map { $0.category })
        let unbudgeted = outflowByCategory.keys.filter { !budgetedSet.contains($0) && !$0.isSystemCategory }
        for cat in unbudgeted {
            let actual = outflowByCategory[cat] ?? 0
            lines.append(.init(
                category: cat,
                target: 0,
                actual: actual,
                remaining: -actual,
                utilization: 0,
                status: .underNoBudget
            ))
        }

        lines.sort { lhs, rhs in
            // Over-budget first, then approaching, then under, then no-budget.
            statusPriority(lhs.status) < statusPriority(rhs.status)
        }

        let totalTarget = lines.reduce(Decimal(0)) { $0 + $1.target }
        let totalActual = lines.reduce(Decimal(0)) { $0 + $1.actual }
        let over = lines.filter { $0.status == .over }
        let noBudget = lines.filter { $0.status == .underNoBudget }

        return BudgetSummary(
            lines: lines,
            totalTarget: totalTarget,
            totalActual: totalActual,
            overCategories: over,
            underNoBudget: noBudget
        )
    }

    private static func statusPriority(_ s: BudgetStatus) -> Int {
        switch s {
        case .over: return 0
        case .approaching: return 1
        case .onTrack: return 2
        case .underNoBudget: return 3
        }
    }
}

private extension TxCategory {
    /// Categories that don't make sense to budget against (transfers, income, etc).
    var isSystemCategory: Bool {
        switch self {
        case .income, .transfer, .savings, .investment, .uncategorized: return true
        default: return false
        }
    }
}
