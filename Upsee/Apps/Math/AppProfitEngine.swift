import Foundation

struct AppProfitability {
    let appName: String
    let grossMonthlyRevenue: Decimal
    let monthlyCosts: Decimal
    let netMonthlyProfit: Decimal
    let netMargin: Double           // 0...1, signed
    /// Cost-aware $/hr — uses net profit, not gross revenue.
    let netRevenuePerHour: Decimal
    let topCostCategory: CostCategory?
    let topCostAmount: Decimal
}

enum AppProfitEngine {
    static func summarize(
        app: AppEntity,
        costs: [AppCost],
        hoursLogged: Double,
        asOf: Date = Date()
    ) -> AppProfitability {
        let appCosts = costs.filter { $0.entityKind == "app" && $0.entityLabel == app.name }
        let monthlyCosts = appCosts.reduce(Decimal(0)) { $0 + $1.monthlyEquivalent(asOf: asOf) }
        let gross = app.monthlyRevenue
        let net = gross - monthlyCosts

        let grossDouble = NSDecimalNumber(decimal: gross).doubleValue
        let netDouble = NSDecimalNumber(decimal: net).doubleValue
        let margin: Double = grossDouble > 0 ? netDouble / grossDouble : 0

        let netPerHour: Decimal = hoursLogged > 0 ? Decimal(netDouble / hoursLogged) : 0

        // Top cost category, summed.
        let byCategory = Dictionary(grouping: appCosts, by: { $0.category })
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.monthlyEquivalent(asOf: asOf) } }
        let top = byCategory.max { lhs, rhs in lhs.value < rhs.value }

        return AppProfitability(
            appName: app.name,
            grossMonthlyRevenue: gross,
            monthlyCosts: monthlyCosts,
            netMonthlyProfit: net,
            netMargin: margin,
            netRevenuePerHour: netPerHour,
            topCostCategory: top?.key,
            topCostAmount: top?.value ?? 0
        )
    }
}
