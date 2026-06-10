import Foundation

struct FinancialHealthInputs {
    var monthlyIncome: Decimal
    var monthlyExpenses: Decimal
    var liquidSavings: Decimal       // cash + investments available as a buffer
    var totalAssets: Decimal
    var totalLiabilities: Decimal
    var monthlyDebtPayments: Decimal
    var largestIncomeShare: Double   // 0…1 — concentration of the biggest income source
}

struct HealthSubscore: Equatable, Identifiable {
    let name: String
    let score: Int           // 0…100, higher is healthier
    let detail: String
    var id: String { name }
}

struct FinancialHealth: Equatable {
    let overall: Int         // 0…100
    let grade: String        // A…F
    let subscores: [HealthSubscore]
    let recommendations: [String]
}

/// Synthesizes the data Upsee already tracks into a single graded financial-health check.
enum FinancialHealthEngine {
    static func assess(_ input: FinancialHealthInputs) -> FinancialHealth {
        let income = dbl(input.monthlyIncome)
        let expenses = dbl(input.monthlyExpenses)
        let liquid = dbl(input.liquidSavings)
        let assets = dbl(input.totalAssets)
        let liabilities = dbl(input.totalLiabilities)
        let debtPayments = dbl(input.monthlyDebtPayments)

        // Emergency fund: months of expenses covered (target 6).
        let months = expenses > 0 ? liquid / expenses : (liquid > 0 ? 12 : 0)
        let emergency = score(clamp(months / 6.0))

        // Savings rate: (income − expenses) / income (target 20%).
        let savingsRate = income > 0 ? (income - expenses) / income : 0
        let savings = score(clamp(savingsRate / 0.20))

        // Debt load: monthly debt payments ÷ income (healthy < 10%, bad > 43%).
        let dti = income > 0 ? debtPayments / income : (debtPayments > 0 ? 1 : 0)
        let debt = score(clamp((0.43 - dti) / 0.33))

        // Leverage: liabilities ÷ assets (healthy < 20%, bad > 80%).
        let leverageRatio = assets > 0 ? liabilities / assets : (liabilities > 0 ? 1 : 0)
        let leverage = score(clamp((0.8 - leverageRatio) / 0.6))

        // Diversification: lower largest-source concentration is healthier.
        let diversification = score(clamp((0.9 - input.largestIncomeShare) / 0.5))

        let subscores = [
            HealthSubscore(name: "Emergency fund", score: emergency, detail: String(format: "%.1f months of expenses", months)),
            HealthSubscore(name: "Savings rate", score: savings, detail: String(format: "%.0f%% of income saved", max(0, savingsRate) * 100)),
            HealthSubscore(name: "Debt load", score: debt, detail: String(format: "%.0f%% of income to debt", dti * 100)),
            HealthSubscore(name: "Leverage", score: leverage, detail: String(format: "%.0f%% liabilities-to-assets", leverageRatio * 100)),
            HealthSubscore(name: "Diversification", score: diversification, detail: String(format: "%.0f%% from top source", input.largestIncomeShare * 100)),
        ]

        let overall = Int((
            Double(emergency) * 0.25 +
            Double(savings) * 0.25 +
            Double(debt) * 0.20 +
            Double(leverage) * 0.15 +
            Double(diversification) * 0.15
        ).rounded())

        var recs: [String] = []
        if emergency < 60 { recs.append("Build your cash buffer toward 6 months of expenses.") }
        if savings < 60 { recs.append("Lift your savings rate — aim for 20% of income.") }
        if debt < 60 { recs.append("Bring debt payments below ~36% of income; run the payoff planner.") }
        if leverage < 60 { recs.append("Pay down liabilities to reduce balance-sheet leverage.") }
        if diversification < 60 { recs.append("Diversify income — you're heavily reliant on one source.") }

        return FinancialHealth(overall: overall, grade: grade(overall), subscores: subscores, recommendations: recs)
    }

    private static func grade(_ score: Int) -> String {
        switch score {
        case 90...: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    private static func score(_ fraction: Double) -> Int { Int((clamp(fraction) * 100).rounded()) }
    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    private static func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}
