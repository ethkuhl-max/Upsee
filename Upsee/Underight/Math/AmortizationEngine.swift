import Foundation

/// One month of a loan amortization schedule.
struct AmortizationMonth: Equatable, Codable {
    let month: Int          // 1-based
    let payment: Decimal
    let interest: Decimal
    let principal: Decimal
    let balance: Decimal     // ending balance after this month's payment
}

/// Annual rollup of an amortization schedule.
struct AmortizationYear: Equatable, Codable {
    let year: Int            // 1-based
    let interestPaid: Decimal
    let principalPaid: Decimal
    let endingBalance: Decimal
}

struct AmortizationSchedule: Equatable, Codable {
    let months: [AmortizationMonth]
    let totalInterest: Decimal
    let totalPrincipal: Decimal

    /// Per-year rollups, grouping the monthly rows into 12-month buckets.
    var years: [AmortizationYear] {
        guard !months.isEmpty else { return [] }
        let yearCount = (months.count + 11) / 12
        return (1...yearCount).map { y in
            let slice = months.filter { ($0.month - 1) / 12 == y - 1 }
            return AmortizationYear(
                year: y,
                interestPaid: slice.reduce(Decimal(0)) { $0 + $1.interest },
                principalPaid: slice.reduce(Decimal(0)) { $0 + $1.principal },
                endingBalance: slice.last?.balance ?? 0
            )
        }
    }

    /// Remaining balance at the end of the given year (0 once the loan is paid off).
    func balance(atEndOfYear year: Int) -> Decimal {
        guard year >= 1 else { return totalPrincipal }
        let targetMonth = year * 12
        if let exact = months.first(where: { $0.month == targetMonth }) { return exact.balance }
        // Past the end of the schedule → fully amortized.
        if targetMonth >= months.count { return 0 }
        return months.last(where: { $0.month <= targetMonth })?.balance ?? 0
    }
}

/// Standard fully-amortizing schedules, for a single loan or a whole financing stack.
enum AmortizationEngine {
    static func schedule(for loan: LoanTerms) -> AmortizationSchedule {
        let principal = dbl(loan.principal)
        let totalMonths = loan.amortizationYears * 12
        guard principal > 0, totalMonths > 0 else {
            return AmortizationSchedule(months: [], totalInterest: 0, totalPrincipal: 0)
        }

        let monthlyRate = loan.annualRate / 12.0
        let payment = dbl(LoanEngine.monthlyPayment(loan))

        var balance = principal
        var rows: [AmortizationMonth] = []
        var totalInterest = 0.0

        for m in 1...totalMonths {
            let interest = balance * monthlyRate
            var principalPaid = payment - interest
            // Final installment (or any rounding overshoot) retires the remaining balance exactly.
            if m == totalMonths || principalPaid > balance {
                principalPaid = balance
            }
            balance -= principalPaid
            if balance < 0 { balance = 0 }
            totalInterest += interest
            rows.append(AmortizationMonth(
                month: m,
                payment: Decimal(interest + principalPaid),
                interest: Decimal(interest),
                principal: Decimal(principalPaid),
                balance: Decimal(balance)
            ))
            if balance <= 0 { break }
        }

        return AmortizationSchedule(
            months: rows,
            totalInterest: Decimal(totalInterest),
            totalPrincipal: loan.principal
        )
    }

    /// Combines each loan's schedule into a single month-by-month stack schedule.
    /// Loans with different terms simply stop contributing once they're paid off.
    static func schedule(for scenario: FinancingScenario) -> AmortizationSchedule {
        let schedules = scenario.loans.map { schedule(for: $0) }
        let maxMonths = schedules.map { $0.months.count }.max() ?? 0
        guard maxMonths > 0 else {
            return AmortizationSchedule(months: [], totalInterest: 0, totalPrincipal: 0)
        }

        var rows: [AmortizationMonth] = []
        for m in 1...maxMonths {
            var payment = Decimal(0)
            var interest = Decimal(0)
            var principal = Decimal(0)
            var balance = Decimal(0)
            for s in schedules where m <= s.months.count {
                let row = s.months[m - 1]
                payment += row.payment
                interest += row.interest
                principal += row.principal
                balance += row.balance
            }
            rows.append(AmortizationMonth(month: m, payment: payment, interest: interest, principal: principal, balance: balance))
        }

        return AmortizationSchedule(
            months: rows,
            totalInterest: schedules.reduce(Decimal(0)) { $0 + $1.totalInterest },
            totalPrincipal: schedules.reduce(Decimal(0)) { $0 + $1.totalPrincipal }
        )
    }
}

private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
