import Foundation

/// Inputs for the deeper acquisition metrics. Defaults are reasonable starting points
/// for a small service business; the buyer tunes them in the report.
struct DealMetricsInputs: Equatable {
    var purchasePrice: Decimal
    var normalizedSDE: Decimal
    var grossRevenue: Decimal?
    var financedPrincipal: Decimal
    var equityInvested: Decimal
    var annualFreeCashFlow: Decimal     // year-1 cash flow to equity, from the returns model
    var workingCapitalPegPct: Double    // NWC needed, as a fraction of revenue
    var tangibleAssetPct: Double        // share of price that is tangible (rest is §197 goodwill)
    var taxRate: Double                 // marginal rate for the goodwill shield
}

/// Institutional-style acquisition metrics layered on top of the base underwriting.
struct DealMetrics: Equatable {
    /// Net working capital a buyer should expect to fund (peg × revenue).
    let workingCapitalPeg: Decimal
    /// Normalized SDE ÷ total debt — a lender's "debt yield" sanity check.
    let debtYield: Double
    /// Intangible value amortized over 15 years under IRC §197.
    let goodwill: Decimal
    let annualGoodwillAmortization: Decimal
    /// Annual cash tax saved by that amortization (amortization × tax rate).
    let annualGoodwillTaxShield: Decimal
    /// Years of year-1 free cash flow to recoup the equity invested.
    let equityPaybackYears: Double?
    /// Return on invested capital = normalized SDE ÷ purchase price.
    let returnOnInvestedCapital: Double
}

enum DealMetricsEngine {
    static func compute(_ input: DealMetricsInputs) -> DealMetrics {
        let price = dbl(input.purchasePrice)
        let sde = dbl(input.normalizedSDE)
        let debt = dbl(input.financedPrincipal)
        let equity = dbl(input.equityInvested)
        let fcf = dbl(input.annualFreeCashFlow)

        // Working capital peg keys off revenue when disclosed; otherwise a price proxy.
        let revenueBase = input.grossRevenue.map(dbl) ?? (price * 0.6)
        let workingCapital = revenueBase * max(0, input.workingCapitalPegPct)

        let debtYield = debt > 0 ? sde / debt : .infinity

        let goodwill = max(0, price * (1 - clamp01(input.tangibleAssetPct)))
        let annualAmort = goodwill / 15.0
        let taxShield = annualAmort * max(0, input.taxRate)

        let payback: Double? = fcf > 0 ? equity / fcf : nil
        let roic = price > 0 ? sde / price : 0

        return DealMetrics(
            workingCapitalPeg: Decimal(workingCapital),
            debtYield: debtYield,
            goodwill: Decimal(goodwill),
            annualGoodwillAmortization: Decimal(annualAmort),
            annualGoodwillTaxShield: Decimal(taxShield),
            equityPaybackYears: payback,
            returnOnInvestedCapital: roic
        )
    }

    private static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
}

private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
