import XCTest
@testable import Upsee

final class WealthEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    func testZeroReturnAccumulatesContributions() {
        let p = WealthEngine.project(startingBalance: 0, monthlyContribution: 100, annualReturn: 0, years: 1)
        XCTAssertEqual(d(p.endingBalance), 1200, accuracy: 0.01)
        XCTAssertEqual(d(p.totalContributed), 1200, accuracy: 0.01)
        XCTAssertEqual(d(p.totalGrowth), 0, accuracy: 0.01)
    }

    func testPositiveReturnProducesGrowth() {
        let p = WealthEngine.project(startingBalance: 10_000, monthlyContribution: 0, annualReturn: 0.12, years: 1)
        XCTAssertGreaterThan(d(p.totalGrowth), 0)
        XCTAssertGreaterThan(d(p.endingBalance), 10_000)
    }

    func testYearsToTargetImmediate() {
        let y = WealthEngine.yearsToTarget(startingBalance: 1000, monthlyContribution: 0, annualReturn: 0.05, target: 1000)
        XCTAssertEqual(y, 0)
    }

    func testYearsToTargetReached() {
        let y = WealthEngine.yearsToTarget(startingBalance: 0, monthlyContribution: 1000, annualReturn: 0, target: 12_000)
        XCTAssertNotNil(y)
        XCTAssertEqual(y!, 1.0, accuracy: 0.001)
    }

    func testMonteCarloIsDeterministicForSeed() {
        let a = WealthEngine.monteCarlo(startingBalance: 10_000, monthlyContribution: 500, annualReturnMean: 0.07, annualReturnStdDev: 0.15, years: 10, target: 100_000, paths: 200, seed: 42)
        let b = WealthEngine.monteCarlo(startingBalance: 10_000, monthlyContribution: 500, annualReturnMean: 0.07, annualReturnStdDev: 0.15, years: 10, target: 100_000, paths: 200, seed: 42)
        XCTAssertEqual(a, b)
        XCTAssertLessThanOrEqual(d(a.endingP10), d(a.endingP50))
        XCTAssertLessThanOrEqual(d(a.endingP50), d(a.endingP90))
        XCTAssertTrue(a.probabilityAboveTarget >= 0 && a.probabilityAboveTarget <= 1)
    }

    func testMonteCarloZeroVolMatchesDeterministic() {
        let mc = WealthEngine.monteCarlo(startingBalance: 10_000, monthlyContribution: 500, annualReturnMean: 0.07, annualReturnStdDev: 0, years: 10, target: 0, paths: 50, seed: 7)
        let proj = WealthEngine.project(startingBalance: 10_000, monthlyContribution: 500, annualReturn: 0.07, years: 10)
        XCTAssertEqual(d(mc.endingP50), d(proj.endingBalance), accuracy: max(1.0, d(proj.endingBalance) * 0.0001))
    }
}
