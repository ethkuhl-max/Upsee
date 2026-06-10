import Foundation

/// One month of a deterministic wealth projection.
struct WealthPoint: Equatable, Codable {
    let month: Int
    let contributed: Decimal   // cumulative contributions (excludes the starting balance)
    let balance: Decimal
}

struct WealthProjection: Equatable, Codable {
    let points: [WealthPoint]
    let endingBalance: Decimal
    let totalContributed: Decimal
    let totalGrowth: Decimal    // ending − starting − contributions (i.e. investment returns)
}

/// Distribution of outcomes from a Monte Carlo simulation.
struct MonteCarloYear: Equatable, Codable {
    let year: Int
    let p10: Decimal
    let p50: Decimal
    let p90: Decimal
}

struct MonteCarloResult: Equatable, Codable {
    let endingP10: Decimal
    let endingP50: Decimal
    let endingP90: Decimal
    let endingMean: Decimal
    let probabilityAboveTarget: Double   // fraction of paths finishing ≥ target
    let perYear: [MonteCarloYear]        // for a fan chart
}

/// Compound investment growth, financial-independence timing, and a Monte Carlo
/// distribution of outcomes. Monthly compounding throughout.
enum WealthEngine {
    static func project(
        startingBalance: Decimal,
        monthlyContribution: Decimal,
        annualReturn: Double,
        years: Int
    ) -> WealthProjection {
        let monthlyRate = annualReturn / 12.0
        let contribution = dbl(monthlyContribution)
        var balance = dbl(startingBalance)
        var contributed = 0.0
        var points: [WealthPoint] = [
            WealthPoint(month: 0, contributed: 0, balance: startingBalance)
        ]

        let totalMonths = max(years, 0) * 12
        if totalMonths > 0 {
            for m in 1...totalMonths {
                balance = balance * (1 + monthlyRate) + contribution
                contributed += contribution
                points.append(WealthPoint(month: m, contributed: Decimal(contributed), balance: Decimal(balance)))
            }
        }

        let growth = balance - dbl(startingBalance) - contributed
        return WealthProjection(
            points: points,
            endingBalance: Decimal(balance),
            totalContributed: Decimal(contributed),
            totalGrowth: Decimal(growth)
        )
    }

    /// Years until the balance first reaches `target`, or nil if it never does within `maxYears`.
    static func yearsToTarget(
        startingBalance: Decimal,
        monthlyContribution: Decimal,
        annualReturn: Double,
        target: Decimal,
        maxYears: Int = 80
    ) -> Double? {
        let goal = dbl(target)
        var balance = dbl(startingBalance)
        if balance >= goal { return 0 }

        let monthlyRate = annualReturn / 12.0
        let contribution = dbl(monthlyContribution)
        let maxMonths = maxYears * 12

        for m in 1...maxMonths {
            balance = balance * (1 + monthlyRate) + contribution
            if balance >= goal { return Double(m) / 12.0 }
        }
        return nil
    }

    static func monteCarlo(
        startingBalance: Decimal,
        monthlyContribution: Decimal,
        annualReturnMean: Double,
        annualReturnStdDev: Double,
        years: Int,
        target: Decimal,
        paths: Int = 500,
        seed: UInt64 = 0x5073_6565_2021
    ) -> MonteCarloResult {
        let totalYears = max(years, 1)
        let contribution = dbl(monthlyContribution)
        let start = dbl(startingBalance)
        let goal = dbl(target)
        let monthlyMean = annualReturnMean / 12.0
        let monthlyStd = annualReturnStdDev / sqrt(12.0)

        var rng = SeededGenerator(seed: seed)

        // balancesByYear[year][path]
        var balancesByYear = Array(repeating: [Double](repeating: 0, count: paths), count: totalYears)
        var endings = [Double](repeating: 0, count: paths)

        for p in 0..<paths {
            var balance = start
            for y in 1...totalYears {
                for _ in 0..<12 {
                    let monthlyReturn = monthlyMean + monthlyStd * nextGaussian(&rng)
                    balance = balance * (1 + monthlyReturn) + contribution
                    if balance < 0 { balance = 0 }
                }
                balancesByYear[y - 1][p] = balance
            }
            endings[p] = balance
        }

        let perYear = (1...totalYears).map { y -> MonteCarloYear in
            let sorted = balancesByYear[y - 1].sorted()
            return MonteCarloYear(
                year: y,
                p10: Decimal(percentile(sorted, 0.10)),
                p50: Decimal(percentile(sorted, 0.50)),
                p90: Decimal(percentile(sorted, 0.90))
            )
        }

        let sortedEndings = endings.sorted()
        let mean = endings.reduce(0, +) / Double(paths)
        let aboveTarget = Double(endings.filter { $0 >= goal }.count) / Double(paths)

        return MonteCarloResult(
            endingP10: Decimal(percentile(sortedEndings, 0.10)),
            endingP50: Decimal(percentile(sortedEndings, 0.50)),
            endingP90: Decimal(percentile(sortedEndings, 0.90)),
            endingMean: Decimal(mean),
            probabilityAboveTarget: aboveTarget,
            perYear: perYear
        )
    }

    // MARK: - Helpers

    private static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let idx = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[min(max(idx, 0), sorted.count - 1)]
    }

    /// Box–Muller transform on the seeded generator for a standard normal sample.
    private static func nextGaussian(_ rng: inout SeededGenerator) -> Double {
        let u1 = Double.random(in: 1e-12...1.0, using: &rng)
        let u2 = Double.random(in: 0.0...1.0, using: &rng)
        return (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
    }
}

/// Deterministic SplitMix64 generator so Monte Carlo runs are reproducible (and testable).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed != 0 ? seed : 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
