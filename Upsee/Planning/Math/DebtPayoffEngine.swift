import Foundation

enum PayoffStrategy: String, CaseIterable, Identifiable {
    case avalanche   // highest APR first — minimizes interest
    case snowball    // smallest balance first — fastest wins

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .avalanche: return "Avalanche (highest rate)"
        case .snowball: return "Snowball (smallest balance)"
        }
    }
}

struct DebtInput: Equatable, Identifiable {
    let id: UUID
    let name: String
    let balance: Decimal
    let apr: Double
    let minimumPayment: Decimal
}

struct DebtPayoffMonth: Equatable, Identifiable {
    let month: Int
    let totalBalance: Decimal
    let interestPaid: Decimal
    let principalPaid: Decimal
    var id: Int { month }
}

struct DebtPayoffResult: Equatable {
    let months: [DebtPayoffMonth]   // total balance trajectory (month 0 = today)
    let monthsToDebtFree: Int?      // nil if not retired within the horizon
    let totalInterestPaid: Decimal
    let payoffOrderNames: [String]  // order debts are cleared
}

/// Simulates the avalanche / snowball "rollover" method: total monthly payment stays
/// fixed (sum of minimums + extra), and each freed-up minimum funnels into the next
/// priority debt until everything is retired.
enum DebtPayoffEngine {
    static func plan(
        debts: [DebtInput],
        strategy: PayoffStrategy,
        extraMonthlyPayment: Decimal = 0,
        maxMonths: Int = 600
    ) -> DebtPayoffResult {
        // Mutable per-debt state in Double for clean amortization.
        var balances = debts.map { dbl($0.balance) }
        let aprs = debts.map { $0.apr }
        let mins = debts.map { dbl($0.minimumPayment) }
        let names = debts.map { $0.name }
        let budget = mins.reduce(0, +) + dbl(extraMonthlyPayment)

        let startTotal = balances.reduce(0, +)
        var months: [DebtPayoffMonth] = [
            DebtPayoffMonth(month: 0, totalBalance: Decimal(startTotal), interestPaid: 0, principalPaid: 0)
        ]

        guard startTotal > 0 else {
            return DebtPayoffResult(months: months, monthsToDebtFree: 0, totalInterestPaid: 0, payoffOrderNames: [])
        }

        var totalInterest = 0.0
        var payoffOrder: [String] = []
        var monthsToFree: Int?

        for month in 1...maxMonths {
            var interestThisMonth = 0.0

            // 1. Accrue interest.
            for i in balances.indices where balances[i] > 0.005 {
                let interest = balances[i] * aprs[i] / 12.0
                balances[i] += interest
                interestThisMonth += interest
            }

            // 2. Pay minimums (capped at the outstanding balance).
            var pool = budget
            for i in balances.indices where balances[i] > 0.005 {
                let pay = min(mins[i], balances[i], pool)
                balances[i] -= pay
                pool -= pay
            }

            // 3. Funnel the remainder to the priority debt(s).
            for i in priorityOrder(balances: balances, aprs: aprs, strategy: strategy) {
                guard pool > 0.005 else { break }
                guard balances[i] > 0.005 else { continue }
                let pay = min(balances[i], pool)
                balances[i] -= pay
                pool -= pay
            }

            // 4. Record any debts cleared this month.
            for i in balances.indices where balances[i] <= 0.005 && !payoffOrder.contains(names[i]) {
                if startBalance(debts, i) > 0 { payoffOrder.append(names[i]) }
                balances[i] = 0
            }

            let total = balances.reduce(0, +)
            totalInterest += interestThisMonth
            months.append(DebtPayoffMonth(
                month: month,
                totalBalance: Decimal(max(0, total)),
                interestPaid: Decimal(interestThisMonth),
                principalPaid: Decimal(max(0, budget - interestThisMonth))
            ))

            if total <= 0.005 {
                monthsToFree = month
                break
            }
            // Guard against negative amortization (budget can't cover interest).
            if month == maxMonths { monthsToFree = nil }
        }

        return DebtPayoffResult(
            months: months,
            monthsToDebtFree: monthsToFree,
            totalInterestPaid: Decimal(totalInterest),
            payoffOrderNames: payoffOrder
        )
    }

    private static func priorityOrder(balances: [Double], aprs: [Double], strategy: PayoffStrategy) -> [Int] {
        let active = balances.indices.filter { balances[$0] > 0.005 }
        switch strategy {
        case .avalanche:
            return active.sorted { aprs[$0] != aprs[$1] ? aprs[$0] > aprs[$1] : balances[$0] < balances[$1] }
        case .snowball:
            return active.sorted { balances[$0] != balances[$1] ? balances[$0] < balances[$1] : aprs[$0] > aprs[$1] }
        }
    }

    private static func startBalance(_ debts: [DebtInput], _ i: Int) -> Double { dbl(debts[i].balance) }
}

private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
