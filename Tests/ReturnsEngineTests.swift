import XCTest
@testable import Upsee

final class ReturnsEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    private func sampleInput(loanPrincipal: Decimal) -> ReturnsInputs {
        ReturnsInputs(
            purchasePrice: 1_000_000,
            loans: [LoanTerms(principal: loanPrincipal, annualRate: 0.10, amortizationYears: 10)],
            normalizedSDE: 200_000,
            ownerSalary: 0,
            sdeGrowthRate: 0,
            holdYears: 5,
            exitMultiple: 3,
            sellingCostRate: 0
        )
    }

    func testIRRSimpleSeries() {
        // Invest 100, receive 110 one year later → 10% IRR.
        let irr = ReturnsEngine.internalRateOfReturn(initialOutflow: 100, inflows: [110])
        XCTAssertEqual(irr, 0.10, accuracy: 0.001)
    }

    func testIRRMultiYear() {
        // Invest 1000, receive 1331 at year 3 → (1.331)^(1/3) − 1 = 10%.
        let irr = ReturnsEngine.internalRateOfReturn(initialOutflow: 1000, inflows: [0, 0, 1331])
        XCTAssertEqual(irr, 0.10, accuracy: 0.001)
    }

    func testEquityInvested() {
        let input = sampleInput(loanPrincipal: 900_000)
        XCTAssertEqual(d(input.equityInvested), 100_000, accuracy: 0.01)
    }

    func testProFormaAndExit() {
        let r = ReturnsEngine.evaluate(sampleInput(loanPrincipal: 900_000))
        XCTAssertEqual(r.proForma.count, 5)
        XCTAssertEqual(d(r.equityInvested), 100_000, accuracy: 0.01)
        // Growth 0, exit multiple 3 on 200k SDE → 600k enterprise value.
        XCTAssertEqual(d(r.exitEnterpriseValue), 600_000, accuracy: 1.0)
        // 5 years into a 10-year loan, debt is not yet retired.
        XCTAssertGreaterThan(d(r.exitDebtPayoff), 0)
        XCTAssertGreaterThan(r.irr, 0)
        XCTAssertGreaterThan(r.cashOnCashYear1, 0)
        XCTAssertGreaterThan(r.equityMultiple, 1)
    }

    func testGrowthRaisesExitValue() {
        var grown = sampleInput(loanPrincipal: 900_000)
        grown.sdeGrowthRate = 0.10
        let flat = ReturnsEngine.evaluate(sampleInput(loanPrincipal: 900_000))
        let up = ReturnsEngine.evaluate(grown)
        XCTAssertGreaterThan(d(up.exitEnterpriseValue), d(flat.exitEnterpriseValue))
    }

    func testZeroEquityIsGuarded() {
        let r = ReturnsEngine.evaluate(sampleInput(loanPrincipal: 1_000_000))
        XCTAssertEqual(d(r.equityInvested), 0, accuracy: 0.01)
        XCTAssertEqual(r.cashOnCashYear1, 0)
        XCTAssertTrue(r.irr.isNaN)
    }
}
