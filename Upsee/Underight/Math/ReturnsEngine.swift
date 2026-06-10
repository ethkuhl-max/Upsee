import Foundation

/// Assumptions that drive the post-acquisition returns model. These are exploratory —
/// the buyer dials them in the report to pressure-test the equity story.
struct ReturnsInputs: Equatable {
    var purchasePrice: Decimal
    var loans: [LoanTerms]
    var normalizedSDE: Decimal
    var ownerSalary: Decimal        // annual draw the buyer pays themselves (reduces FCF to equity)
    var sdeGrowthRate: Double       // annual SDE growth
    var holdYears: Int
    var exitMultiple: Double        // applied to the exit-year SDE
    var sellingCostRate: Double     // transaction costs at exit, as a fraction of enterprise value

    /// Cash the buyer must put in to close: purchase price not covered by debt.
    var equityInvested: Decimal {
        let financed = loans.reduce(Decimal(0)) { $0 + $1.principal }
        return max(purchasePrice - financed, 0)
    }
}

/// One year of the post-acquisition pro forma.
struct YearProForma: Equatable, Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let sde: Decimal
    let debtService: Decimal
    let interest: Decimal
    let principal: Decimal
    let freeCashFlow: Decimal       // SDE − debt service − owner salary
    let loanBalance: Decimal        // end of year
    let cumulativeCashFlow: Decimal
}

struct ReturnsSummary: Equatable, Codable {
    let equityInvested: Decimal
    let proForma: [YearProForma]
    let cashOnCashYear1: Double       // year-1 FCF ÷ equity
    let averageCashOnCash: Double
    let exitEnterpriseValue: Decimal  // exit-year SDE × exit multiple
    let exitDebtPayoff: Decimal       // remaining loan balance at exit
    let exitEquityProceeds: Decimal   // EV − debt − selling costs
    let totalProfit: Decimal          // Σ FCF + exit proceeds − equity
    let equityMultiple: Double        // (Σ FCF + exit proceeds) ÷ equity
    let irr: Double                   // annualized, NaN if not solvable
}

enum ReturnsEngine {
    static func evaluate(_ input: ReturnsInputs) -> ReturnsSummary {
        let holdYears = max(input.holdYears, 1)
        let equity = dbl(input.equityInvested)
        let sdeBase = dbl(input.normalizedSDE)
        let ownerSalary = dbl(input.ownerSalary)

        let scenario = FinancingScenario(label: "stack", loans: input.loans, buyerEquity: input.equityInvested)
        let years = AmortizationEngine.schedule(for: scenario).years

        var proForma: [YearProForma] = []
        var cumulative = 0.0
        var freeCashFlows: [Double] = []

        for y in 1...holdYears {
            let sde = sdeBase * pow(1 + input.sdeGrowthRate, Double(y - 1))
            let yearRow = y <= years.count ? years[y - 1] : nil
            let interest = yearRow.map { dbl($0.interestPaid) } ?? 0
            let principal = yearRow.map { dbl($0.principalPaid) } ?? 0
            let debtService = interest + principal
            let balance = yearRow.map { dbl($0.endingBalance) } ?? 0
            let fcf = sde - debtService - ownerSalary
            cumulative += fcf
            freeCashFlows.append(fcf)
            proForma.append(YearProForma(
                year: y,
                sde: Decimal(sde),
                debtService: Decimal(debtService),
                interest: Decimal(interest),
                principal: Decimal(principal),
                freeCashFlow: Decimal(fcf),
                loanBalance: Decimal(balance),
                cumulativeCashFlow: Decimal(cumulative)
            ))
        }

        let exitSDE = sdeBase * pow(1 + input.sdeGrowthRate, Double(holdYears - 1))
        let exitEV = exitSDE * input.exitMultiple
        let exitDebt = proForma.last.map { dbl($0.loanBalance) } ?? 0
        let sellingCosts = exitEV * input.sellingCostRate
        let exitEquityProceeds = max(exitEV - exitDebt - sellingCosts, 0)

        let totalCashReturned = freeCashFlows.reduce(0, +) + exitEquityProceeds
        let cashOnCash1 = equity > 0 ? freeCashFlows[0] / equity : 0
        let avgCashOnCash = equity > 0 ? (freeCashFlows.reduce(0, +) / Double(holdYears)) / equity : 0
        let equityMultiple = equity > 0 ? totalCashReturned / equity : 0

        var irr = Double.nan
        if equity > 0 {
            var flows = freeCashFlows
            flows[flows.count - 1] += exitEquityProceeds
            irr = internalRateOfReturn(initialOutflow: equity, inflows: flows)
        }

        return ReturnsSummary(
            equityInvested: input.equityInvested,
            proForma: proForma,
            cashOnCashYear1: cashOnCash1,
            averageCashOnCash: avgCashOnCash,
            exitEnterpriseValue: Decimal(exitEV),
            exitDebtPayoff: Decimal(exitDebt),
            exitEquityProceeds: Decimal(exitEquityProceeds),
            totalProfit: Decimal(totalCashReturned - equity),
            equityMultiple: equityMultiple,
            irr: irr
        )
    }

    /// Solves NPV = 0 for the discount rate via bisection. `inflows[i]` lands in year i+1.
    /// Returns NaN when no sign change exists in the search range.
    static func internalRateOfReturn(initialOutflow: Double, inflows: [Double]) -> Double {
        func npv(_ rate: Double) -> Double {
            var total = -initialOutflow
            for (i, cf) in inflows.enumerated() {
                total += cf / pow(1 + rate, Double(i + 1))
            }
            return total
        }

        var low = -0.9999
        var high = 10.0
        let nLow = npv(low)
        var nHigh = npv(high)
        // Extend the upper bound for very high-return deals.
        var expand = 0
        while nLow.sign == nHigh.sign && expand < 6 {
            high *= 2
            nHigh = npv(high)
            expand += 1
        }
        guard nLow.sign != nHigh.sign else { return .nan }

        for _ in 0..<200 {
            let mid = (low + high) / 2
            let nMid = npv(mid)
            if abs(nMid) < 1e-6 { return mid }
            if nMid.sign == nLow.sign { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }
}

private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
