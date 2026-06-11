import XCTest
@testable import Upsee

final class RothConversionEngineTests: XCTestCase {
    func testZeroConversionHasZeroTax() {
        let p = RothConversionEngine.plan(baseTaxableIncome: 50_000, conversionAmount: 0, filingStatus: .single)
        XCTAssertEqual(NSDecimalNumber(decimal: p.totalTax).doubleValue, 0, accuracy: 0.01)
    }

    func testTaxAtSingleBracketRate() {
        // Single filer with ~$20k taxable (below standard deduction zone) converting $5k → all in 10%.
        let p = RothConversionEngine.plan(baseTaxableIncome: 5_000, conversionAmount: 5_000, filingStatus: .single)
        XCTAssertEqual(p.effectiveRate, 0.10, accuracy: 0.01)
    }

    func testMarginalReachedReflectsHighestBracketTouched() {
        // Single filer at $50k taxable income, convert $200k → spills into 22% / 24%.
        let p = RothConversionEngine.plan(baseTaxableIncome: 50_000, conversionAmount: 200_000, filingStatus: .single)
        XCTAssertGreaterThanOrEqual(p.marginalRateReached, 0.22)
    }

    func testRecommendedFillIsPositive() {
        let p = RothConversionEngine.plan(baseTaxableIncome: 5_000, conversionAmount: 20_000, filingStatus: .single)
        XCTAssertGreaterThan(NSDecimalNumber(decimal: p.recommendedFill).doubleValue, 0)
    }

    func testMarriedHigherBracketsAccommodateMoreFill() {
        let single = RothConversionEngine.plan(baseTaxableIncome: 50_000, conversionAmount: 50_000, filingStatus: .single)
        let married = RothConversionEngine.plan(baseTaxableIncome: 50_000, conversionAmount: 50_000, filingStatus: .marriedJoint)
        // Married brackets are wider, so married pays less tax on the same conversion.
        XCTAssertLessThan(
            NSDecimalNumber(decimal: married.totalTax).doubleValue,
            NSDecimalNumber(decimal: single.totalTax).doubleValue
        )
    }
}
