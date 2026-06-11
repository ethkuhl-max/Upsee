import Foundation

struct AmortizationLine: Equatable {
    let monthIndex: Int            // 1-based
    let date: Date
    let payment: Decimal
    let principal: Decimal
    let interest: Decimal
    let extra: Decimal
    let endingBalance: Decimal
    let cumulativeInterest: Decimal
}

struct LoanSchedule {
    let lines: [AmortizationLine]
    /// Payoff date — last non-zero balance line's date.
    let payoffDate: Date?
    let totalInterest: Decimal
    let totalPaid: Decimal
    /// Months saved vs the original term by applying `extraPayment`.
    let monthsSaved: Int
    /// Dollars of interest saved vs the original-term schedule.
    let interestSaved: Decimal
}

enum LoanScheduleEngine {
    /// Standard mortgage-style amortization. If `extraPayment > 0`, applies
    /// it as additional principal each month and compares to the no-extra
    /// schedule for savings.
    static func schedule(
        principal: Decimal,
        apr: Double,
        termMonths: Int,
        monthlyPayment: Decimal,
        extraPayment: Decimal = 0,
        startDate: Date = Date()
    ) -> LoanSchedule {
        let baseLines = run(
            principal: principal,
            apr: apr,
            termMonths: termMonths,
            monthlyPayment: monthlyPayment,
            extraPayment: 0,
            startDate: startDate
        )
        let extraLines = extraPayment > 0
            ? run(principal: principal, apr: apr, termMonths: termMonths,
                  monthlyPayment: monthlyPayment, extraPayment: extraPayment, startDate: startDate)
            : baseLines

        let final = extraLines.last
        let totalInterest = final?.cumulativeInterest ?? 0
        let totalPaid = extraLines.reduce(Decimal(0)) { $0 + $1.payment + $1.extra }

        let monthsSaved = max(0, baseLines.count - extraLines.count)
        let interestSaved: Decimal = {
            let baseInterest = baseLines.last?.cumulativeInterest ?? 0
            let extraInterest = extraLines.last?.cumulativeInterest ?? 0
            return max(0, baseInterest - extraInterest)
        }()

        return LoanSchedule(
            lines: extraLines,
            payoffDate: final?.date,
            totalInterest: totalInterest,
            totalPaid: totalPaid,
            monthsSaved: monthsSaved,
            interestSaved: interestSaved
        )
    }

    /// Solve for the standard monthly payment given principal, APR, term.
    /// Useful when the user only knows the loan terms, not the payment.
    static func standardMonthlyPayment(principal: Decimal, apr: Double, termMonths: Int) -> Decimal {
        let p = NSDecimalNumber(decimal: principal).doubleValue
        let r = apr / 12.0
        let n = Double(termMonths)
        guard p > 0, n > 0 else { return 0 }
        if r == 0 { return Decimal(p / n) }
        let payment = (p * r) / (1 - pow(1 + r, -n))
        return Decimal(payment)
    }

    private static func run(
        principal: Decimal,
        apr: Double,
        termMonths: Int,
        monthlyPayment: Decimal,
        extraPayment: Decimal,
        startDate: Date
    ) -> [AmortizationLine] {
        var lines: [AmortizationLine] = []
        var balance = NSDecimalNumber(decimal: principal).doubleValue
        let r = apr / 12.0
        let pay = NSDecimalNumber(decimal: monthlyPayment).doubleValue
        let extra = NSDecimalNumber(decimal: extraPayment).doubleValue
        var cumulativeInterest = 0.0

        let cal = Calendar.current
        // Cap at termMonths so a misconfigured payment (less than interest)
        // doesn't run forever.
        for m in 1...max(termMonths, 1) {
            let interest = balance * r
            var principalPortion = max(0, pay - interest)
            var extraPortion = extra
            if principalPortion + extraPortion > balance {
                let remaining = balance
                if principalPortion >= remaining {
                    principalPortion = remaining
                    extraPortion = 0
                } else {
                    extraPortion = remaining - principalPortion
                }
            }
            balance -= (principalPortion + extraPortion)
            cumulativeInterest += interest
            let date = cal.date(byAdding: .month, value: m, to: startDate) ?? startDate
            lines.append(AmortizationLine(
                monthIndex: m,
                date: date,
                payment: Decimal(pay),
                principal: Decimal(principalPortion),
                interest: Decimal(interest),
                extra: Decimal(extraPortion),
                endingBalance: Decimal(max(0, balance)),
                cumulativeInterest: Decimal(cumulativeInterest)
            ))
            if balance <= 0.01 { break }
        }
        return lines
    }
}
