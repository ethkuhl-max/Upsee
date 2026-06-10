import XCTest
@testable import Upsee

final class IncomeTaxEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    func testMarginalStackingSingle() {
        // Taxable 50,000 single → 11925@10 + 36550@12 + 1525@22 = 5,914.
        let result = IncomeTaxEngine.federalTax(taxable: 50_000, status: .single)
        XCTAssertEqual(result.tax, 5_914, accuracy: 0.5)
        XCTAssertEqual(result.marginal, 0.22)
    }

    func testStandardDeductionApplied() {
        // 65k gross single, no SE → taxable 50k → federal 5,914.
        let b = IncomeTaxEngine.calculate(grossIncome: 65_000, selfEmploymentIncome: 0, filingStatus: .single, stateRate: 0)
        XCTAssertEqual(d(b.taxableIncome), 50_000, accuracy: 0.5)
        XCTAssertEqual(d(b.federalTax), 5_914, accuracy: 0.5)
        XCTAssertEqual(d(b.selfEmploymentTax), 0, accuracy: 0.01)
    }

    func testSelfEmploymentTaxPresent() {
        let b = IncomeTaxEngine.calculate(grossIncome: 100_000, selfEmploymentIncome: 100_000, filingStatus: .single, stateRate: 0)
        XCTAssertGreaterThan(d(b.selfEmploymentTax), 0)
        // SE tax ≈ 100000 * 0.9235 * 0.153 ≈ 14,130.
        XCTAssertEqual(d(b.selfEmploymentTax), 14_130, accuracy: 50)
    }

    func testStateTaxFlat() {
        let b = IncomeTaxEngine.calculate(grossIncome: 100_000, selfEmploymentIncome: 0, filingStatus: .single, stateRate: 0.05)
        XCTAssertEqual(d(b.stateTax), d(b.taxableIncome) * 0.05, accuracy: 0.5)
    }

    func testEffectiveBelowMarginal() {
        let b = IncomeTaxEngine.calculate(grossIncome: 250_000, selfEmploymentIncome: 0, filingStatus: .single, stateRate: 0)
        XCTAssertLessThan(b.effectiveRate, b.marginalRate)
        XCTAssertGreaterThan(b.effectiveRate, 0)
    }

    func testMarriedBracketsAreWider() {
        let single = IncomeTaxEngine.calculate(grossIncome: 200_000, selfEmploymentIncome: 0, filingStatus: .single, stateRate: 0)
        let married = IncomeTaxEngine.calculate(grossIncome: 200_000, selfEmploymentIncome: 0, filingStatus: .marriedJoint, stateRate: 0)
        XCTAssertLessThan(d(married.federalTax), d(single.federalTax))
    }

    func testZeroIncomeZeroTax() {
        let b = IncomeTaxEngine.calculate(grossIncome: 0, selfEmploymentIncome: 0, filingStatus: .single, stateRate: 0.05)
        XCTAssertEqual(d(b.totalTax), 0, accuracy: 0.01)
        XCTAssertEqual(b.effectiveRate, 0)
    }
}
