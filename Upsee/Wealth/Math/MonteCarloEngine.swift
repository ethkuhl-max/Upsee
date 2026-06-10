import Foundation

struct WealthMonteCarloPoint: Equatable, Identifiable {
    var id: Int { yearIndex }
    let yearIndex: Int
    let date: Date
    let p10: Decimal
    let p50: Decimal
    let p90: Decimal
    let mean: Decimal
}

struct WealthMonteCarloResult: Equatable {
    let points: [WealthMonteCarloPoint]
    let yearsAhead: Int
    let paths: Int
    let expectedReturn: Double
    let volatility: Double
    /// Probability that the median path reaches or exceeds `targetAmount`. Nil if
    /// no target was provided.
    let probabilityOfTarget: Double?

    var endingMedian: Decimal { points.last?.p50 ?? 0 }
    var endingP10: Decimal { points.last?.p10 ?? 0 }
    var endingP90: Decimal { points.last?.p90 ?? 0 }
}

/// Stochastic wealth projection using lognormal returns. Deterministic engines
/// (`CashFlowEngine`, `MultipleEngine`) are tested precisely; this one is tested
/// for shape and edge cases only — the seed isn't injected, so absolute values
/// vary run-to-run.
enum MonteCarloEngine {
    static func project(
        startingBalance: Decimal,
        annualContribution: Decimal,
        yearsAhead: Int,
        expectedReturn: Double = 0.07,
        volatility: Double = 0.15,
        targetAmount: Decimal? = nil,
        paths: Int = 1000
    ) -> WealthMonteCarloResult {
        guard yearsAhead > 0, paths > 0 else {
            return WealthMonteCarloResult(
                points: [],
                yearsAhead: yearsAhead,
                paths: paths,
                expectedReturn: expectedReturn,
                volatility: volatility,
                probabilityOfTarget: nil
            )
        }

        let start = NSDecimalNumber(decimal: startingBalance).doubleValue
        let contribution = NSDecimalNumber(decimal: annualContribution).doubleValue

        // Simulate all paths, store final ending balances per year column.
        var matrix: [[Double]] = Array(repeating: Array(repeating: 0, count: paths), count: yearsAhead + 1)
        for pathIndex in 0..<paths {
            var balance = start
            matrix[0][pathIndex] = balance
            for year in 1...yearsAhead {
                let sample = normalSample()
                // Lognormal-style growth: balance * exp((mu - 0.5*sigma^2) + sigma * z)
                let drift = expectedReturn - 0.5 * volatility * volatility
                let factor = exp(drift + volatility * sample)
                balance = balance * factor + contribution
                matrix[year][pathIndex] = balance
            }
        }

        var points: [WealthMonteCarloPoint] = []
        let cal = Calendar.current
        let now = Date()
        for year in 0...yearsAhead {
            var column = matrix[year]
            column.sort()
            let p10 = column[Int(Double(paths) * 0.10)]
            let p50 = column[paths / 2]
            let p90 = column[Int(Double(paths) * 0.90)]
            let mean = column.reduce(0, +) / Double(paths)
            let date = cal.date(byAdding: .year, value: year, to: now) ?? now
            points.append(WealthMonteCarloPoint(
                yearIndex: year,
                date: date,
                p10: Decimal(p10),
                p50: Decimal(p50),
                p90: Decimal(p90),
                mean: Decimal(mean)
            ))
        }

        var probability: Double?
        if let target = targetAmount {
            let targetDouble = NSDecimalNumber(decimal: target).doubleValue
            let lastColumn = matrix[yearsAhead]
            let hits = lastColumn.filter { $0 >= targetDouble }.count
            probability = Double(hits) / Double(paths)
        }

        return WealthMonteCarloResult(
            points: points,
            yearsAhead: yearsAhead,
            paths: paths,
            expectedReturn: expectedReturn,
            volatility: volatility,
            probabilityOfTarget: probability
        )
    }

    /// Box-Muller transform for normally distributed random samples.
    private static func normalSample() -> Double {
        let u1 = max(.leastNormalMagnitude, Double.random(in: 0..<1))
        let u2 = Double.random(in: 0..<1)
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }
}
