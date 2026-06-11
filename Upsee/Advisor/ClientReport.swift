import Foundation

/// Generates client-facing Markdown documents — a financial-plan summary and an
/// Investment Policy Statement — by reusing Upsee's existing planning engines.
enum ClientReport {
    // MARK: - Financial plan summary

    static func planSummary(for client: Client) -> String {
        var out: [String] = []
        out.append("# \(client.name) — Financial Plan Summary")
        out.append("_Prepared \(longDate(Date()))_")
        out.append("")

        let netWorth = NetWorthEngine.summarize(client.lineItems)
        out.append("## Net worth")
        out.append("- **Total assets:** \(money(netWorth.totalAssets))")
        out.append("- **Total liabilities:** \(money(netWorth.totalLiabilities))")
        out.append("- **Net worth:** \(money(netWorth.netWorth))")
        out.append("")

        out.append("## Cash flow")
        let surplus = client.monthlyIncome - client.monthlyExpenses
        out.append("- **Monthly income:** \(money(client.monthlyIncome))")
        out.append("- **Monthly expenses:** \(money(client.monthlyExpenses))")
        out.append("- **Monthly surplus:** \(money(surplus))")
        out.append("")

        if !client.goals.isEmpty {
            out.append("## Goals")
            for goal in client.goals {
                let pct = Int((goal.progress * 100).rounded())
                var line = "- **\(goal.name):** \(money(goal.currentAmount)) of \(money(goal.targetAmount)) (\(pct)%)"
                if goal.progress < 1, let date = goal.projectedHitDate(monthlyContribution: max(0, surplus)) {
                    let f = DateFormatter(); f.dateFormat = "MMM yyyy"
                    line += " — projected \(f.string(from: date))"
                }
                out.append(line)
            }
            out.append("")
        }

        let health = FinancialHealthEngine.assess(healthInputs(for: client, netWorth: netWorth))
        out.append("## Financial health: \(health.grade) (\(health.overall)/100)")
        for sub in health.subscores {
            out.append("- **\(sub.name):** \(sub.score)/100 — \(sub.detail)")
        }
        if !health.recommendations.isEmpty {
            out.append("")
            out.append("### Recommendations")
            for rec in health.recommendations { out.append("- \(rec)") }
        }
        out.append("")

        if !client.riskAnswers.isEmpty {
            let profile = RiskProfileEngine.score(answers: client.riskAnswers)
            out.append("## Risk profile & target allocation")
            out.append("- **Risk profile:** \(profile.band.displayName) (\(profile.score)/100)")
            out.append("- **Target allocation:** \(profile.equityPct)% equities / \(profile.bondPct)% bonds / \(profile.cashPct)% cash")
            out.append("")

            let mc = monteCarlo(for: client, profile: profile)
            out.append("## 20-year projection (Monte Carlo)")
            out.append("- **Downside (10th pct):** \(money(mc.endingP10))")
            out.append("- **Median:** \(money(mc.endingP50))")
            out.append("- **Upside (90th pct):** \(money(mc.endingP90))")
            out.append("")
        }

        out.append("---")
        out.append("_Estimate only. Not a guarantee of future results. Prepared with Upsee._")
        return out.joined(separator: "\n")
    }

    // MARK: - Prospect proposal

    static func proposal(for client: Client) -> String {
        var out: [String] = []
        out.append("# Proposal for \(client.name)")
        out.append("_Prepared \(longDate(Date()))_")
        out.append("")
        out.append("Thank you for the opportunity to work together. This proposal outlines how we'd structure and manage your portfolio.")
        out.append("")

        out.append("## What we'd manage")
        out.append("- **Assets under management:** \(money(client.aum))")
        out.append("- **Advisory fee:** \(String(format: "%.2f%%", client.feePercent * 100)) per year (\(money(client.annualFeeRevenue)) annually)")
        out.append("- **Review cadence:** every \(client.reviewCadenceMonths) months")
        out.append("")

        if !client.riskAnswers.isEmpty {
            let profile = RiskProfileEngine.score(answers: client.riskAnswers)
            out.append("## Your risk profile")
            out.append("Based on your questionnaire, you're **\(profile.band.displayName)** (\(profile.score)/100). We'd target:")
            out.append("- \(profile.equityPct)% equities")
            out.append("- \(profile.bondPct)% fixed income")
            out.append("- \(profile.cashPct)% cash")
            out.append("")

            let mc = monteCarlo(for: client, profile: profile)
            out.append("## Where this could go (20 years)")
            out.append("Investing \(money(max(0, client.monthlyIncome - client.monthlyExpenses)))/mo of surplus at your target allocation:")
            out.append("- **Likely (median):** \(money(mc.endingP50))")
            out.append("- **Downside (10th pct):** \(money(mc.endingP10))")
            out.append("- **Upside (90th pct):** \(money(mc.endingP90))")
            out.append("")
        } else {
            out.append("## Next: risk profiling")
            out.append("We'll complete a short risk questionnaire to set your target allocation.")
            out.append("")
        }

        if !client.goals.isEmpty {
            out.append("## Goals we'll plan around")
            for goal in client.goals {
                out.append("- **\(goal.name):** \(money(goal.targetAmount)) target")
            }
            out.append("")
        }

        out.append("## Next steps")
        out.append("1. Sign the advisory agreement and Investment Policy Statement.")
        out.append("2. Open / transfer accounts to custody.")
        out.append("3. Implement the target allocation and schedule your first review.")
        out.append("")
        out.append("---")
        out.append("_Illustrative only. Not a guarantee of future results._")
        return out.joined(separator: "\n")
    }

    // MARK: - Investment Policy Statement

    static func investmentPolicyStatement(for client: Client) -> String {
        let profile = client.riskAnswers.isEmpty ? nil : RiskProfileEngine.score(answers: client.riskAnswers)
        var out: [String] = []
        out.append("# Investment Policy Statement")
        out.append("## \(client.name)")
        out.append("_Effective \(longDate(Date()))_")
        out.append("")

        out.append("## 1. Objective")
        out.append("This statement establishes the investment objectives, risk tolerance, and asset-allocation policy for \(client.name)'s portfolio of \(money(client.aum)) under management.")
        out.append("")

        out.append("## 2. Risk tolerance")
        if let profile {
            out.append("Based on the completed risk questionnaire, the client is assessed as **\(profile.band.displayName)** (score \(profile.score)/100).")
        } else {
            out.append("_Risk questionnaire not yet completed._")
        }
        out.append("")

        out.append("## 3. Target asset allocation")
        if let profile {
            out.append("| Asset class | Target |")
            out.append("| --- | --- |")
            out.append("| Equities | \(profile.equityPct)% |")
            out.append("| Fixed income | \(profile.bondPct)% |")
            out.append("| Cash | \(profile.cashPct)% |")
        } else {
            out.append("_To be determined upon risk profiling._")
        }
        out.append("")

        out.append("## 4. Constraints & guidelines")
        out.append("- Rebalance when any asset class drifts more than ±5% from target.")
        out.append("- Maintain at least 3 months of expenses in cash reserves.")
        out.append("- Advisory fee: \(String(format: "%.2f%%", client.feePercent * 100)) of assets annually.")
        out.append("")

        out.append("## 5. Review")
        out.append("- Portfolio reviewed every \(client.reviewCadenceMonths) months.")
        if let next = client.nextReviewDate {
            out.append("- Next scheduled review: \(longDate(next)).")
        }
        out.append("")

        out.append("---")
        out.append("_Advisor: ____________________   Client: ____________________   Date: ___________")
        return out.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func healthInputs(for client: Client, netWorth: NetWorthSummary) -> FinancialHealthInputs {
        let liquid = client.lineItems
            .filter { $0.isAsset && ($0.category.lowercased().contains("cash") || $0.category.lowercased().contains("invest")) }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let liquidSavings = liquid > 0 ? liquid : netWorth.totalAssets
        return FinancialHealthInputs(
            monthlyIncome: client.monthlyIncome,
            monthlyExpenses: client.monthlyExpenses,
            liquidSavings: liquidSavings,
            totalAssets: netWorth.totalAssets,
            totalLiabilities: netWorth.totalLiabilities,
            monthlyDebtPayments: 0,
            largestIncomeShare: 0.5
        )
    }

    private static func monteCarlo(for client: Client, profile: RiskProfile) -> MonteCarloResult {
        let investable = client.lineItems.filter(\.isAsset).reduce(Decimal(0)) { $0 + $1.amount }
        let surplus = max(0, client.monthlyIncome - client.monthlyExpenses)
        let mean = expectedReturn(profile)
        let vol = Double(profile.equityPct) / 100.0 * 0.18
        return WealthEngine.monteCarlo(
            startingBalance: investable,
            monthlyContribution: surplus,
            annualReturnMean: mean,
            annualReturnStdDev: vol,
            years: 20,
            target: investable,
            paths: 400
        )
    }

    private static func expectedReturn(_ p: RiskProfile) -> Double {
        let e = Double(p.equityPct) / 100.0
        let b = Double(p.bondPct) / 100.0
        let c = Double(p.cashPct) / 100.0
        return e * 0.08 + b * 0.035 + c * 0.01
    }

    private static func money(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencyCode = "USD"
        return f.string(from: NSDecimalNumber(decimal: d)) ?? "$0"
    }

    private static func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }
}
