import Foundation

enum MultipleVerdict: String, Codable, Equatable {
    case underMedian      // priced below the industry median — attractive
    case atMedian         // within a tight band around median
    case aboveMedian      // priced above median but inside the high
    case priceyOutlier    // above industry high — needs an extraordinary justification

    var label: String {
        switch self {
        case .underMedian:    return "Below median — attractive"
        case .atMedian:       return "At industry median"
        case .aboveMedian:    return "Above median — needs a story"
        case .priceyOutlier:  return "Above industry high — outlier"
        }
    }
}

struct MultipleReading: Codable, Equatable {
    let askedMultiple: Double
    let industryRange: IndustryMultipleRange
    let verdict: MultipleVerdict
    let category: IndustryCategory
    /// The value the multiple was taken against (revenue or normalized SDE). Optional for
    /// backward compatibility with analyses saved before the basis was tracked.
    var denominator: Decimal? = nil
    var usedRevenueBasis: Bool? = nil

    /// "revenue" or "SDE" — what the asked multiple is a multiple of.
    var basisLabel: String { (usedRevenueBasis ?? false) ? "revenue" : "SDE" }
}

enum MultipleEngine {
    /// Reads asking price ÷ (revenue or normalized SDE) against the industry comparable range.
    /// Revenue-based industries (dental, law, accounting, medical) use gross revenue when it's
    /// available; otherwise the read falls back to SDE.
    static func read(
        askingPrice: Decimal,
        normalizedSDE: Decimal,
        grossRevenue: Decimal? = nil,
        category: IndustryCategory
    ) -> MultipleReading {
        let range = IndustryComps.range(for: category)
        let useRevenue = range.valuationBasis == .revenue && dbl(grossRevenue ?? 0) > 0
        let denominatorDecimal: Decimal = useRevenue ? (grossRevenue ?? 0) : normalizedSDE

        let asking = dbl(askingPrice)
        let denominator = dbl(denominatorDecimal)
        let asked = denominator > 0 ? asking / denominator : .infinity

        let medianBandHalf = (range.high - range.low) * 0.10  // ±10% of range = "at median"

        let verdict: MultipleVerdict
        if asked < range.median - medianBandHalf {
            verdict = .underMedian
        } else if asked <= range.median + medianBandHalf {
            verdict = .atMedian
        } else if asked <= range.high {
            verdict = .aboveMedian
        } else {
            verdict = .priceyOutlier
        }

        return MultipleReading(
            askedMultiple: asked,
            industryRange: range,
            verdict: verdict,
            category: category,
            denominator: denominatorDecimal,
            usedRevenueBasis: useRevenue
        )
    }

    private static func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}
