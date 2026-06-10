import XCTest
@testable import Upsee

final class DealMetricsEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    private func sampleInput() -> DealMetricsInputs {
        DealMetricsInputs(
            purchasePrice: 1_000_000,
            normalizedSDE: 250_000,
            grossRevenue: 1_200_000,
            financedPrincipal: 900_000,
            equityInvested: 100_000,
            annualFreeCashFlow: 50_000,
            workingCapitalPegPct: 0.10,
            tangibleAssetPct: 0.20,
            taxRate: 0.30
        )
    }

    func testWorkingCapitalPeg() {
        let m = DealMetricsEngine.compute(sampleInput())
        XCTAssertEqual(d(m.workingCapitalPeg), 120_000, accuracy: 0.5) // 10% of 1.2M revenue
    }

    func testDebtYield() {
        let m = DealMetricsEngine.compute(sampleInput())
        XCTAssertEqual(m.debtYield, 250_000.0 / 900_000.0, accuracy: 0.0001)
    }

    func testGoodwillAndShield() {
        let m = DealMetricsEngine.compute(sampleInput())
        XCTAssertEqual(d(m.goodwill), 800_000, accuracy: 0.5)          // 80% intangible
        XCTAssertEqual(d(m.annualGoodwillAmortization), 800_000 / 15, accuracy: 0.5)
        XCTAssertEqual(d(m.annualGoodwillTaxShield), (800_000 / 15) * 0.30, accuracy: 0.5)
    }

    func testPaybackAndROIC() {
        let m = DealMetricsEngine.compute(sampleInput())
        XCTAssertEqual(m.equityPaybackYears!, 100_000.0 / 50_000.0, accuracy: 0.001) // 2 years
        XCTAssertEqual(m.returnOnInvestedCapital, 0.25, accuracy: 0.0001)            // 250k / 1M
    }

    func testRevenueFallbackWhenNil() {
        var input = sampleInput()
        input.grossRevenue = nil
        let m = DealMetricsEngine.compute(input)
        // Falls back to 60% of price as a revenue proxy → 600k * 10% = 60k.
        XCTAssertEqual(d(m.workingCapitalPeg), 60_000, accuracy: 0.5)
    }

    func testZeroCashFlowPaybackIsNil() {
        var input = sampleInput()
        input.annualFreeCashFlow = 0
        let m = DealMetricsEngine.compute(input)
        XCTAssertNil(m.equityPaybackYears)
    }
}
