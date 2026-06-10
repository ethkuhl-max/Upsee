import XCTest
@testable import Upsee

final class MultipleEngineTests: XCTestCase {
    func testUnderMedianHVACDeal() {
        // HVAC median ~2.8x. $600k SDE * 2.2x = $1.32M asking.
        let r = MultipleEngine.read(askingPrice: 1_320_000, normalizedSDE: 600_000, category: .hvac)
        XCTAssertEqual(r.verdict, .underMedian)
    }

    func testAtMedianHVACDeal() {
        // 2.8x of $400k = $1.12M
        let r = MultipleEngine.read(askingPrice: 1_120_000, normalizedSDE: 400_000, category: .hvac)
        XCTAssertEqual(r.verdict, .atMedian)
    }

    func testAboveMedianButInRange() {
        // 3.2x of $400k = $1.28M (HVAC range 2.0–3.5)
        let r = MultipleEngine.read(askingPrice: 1_280_000, normalizedSDE: 400_000, category: .hvac)
        XCTAssertEqual(r.verdict, .aboveMedian)
    }

    func testPriceyOutlierDeal() {
        // 5x of $400k = $2M, well above HVAC high of 3.5
        let r = MultipleEngine.read(askingPrice: 2_000_000, normalizedSDE: 400_000, category: .hvac)
        XCTAssertEqual(r.verdict, .priceyOutlier)
    }

    func testAskedMultipleMath() {
        let r = MultipleEngine.read(askingPrice: 1_000_000, normalizedSDE: 250_000, category: .laundromat)
        XCTAssertEqual(r.askedMultiple, 4.0, accuracy: 0.001)
    }

    func testZeroSDEHandledSafely() {
        let r = MultipleEngine.read(askingPrice: 500_000, normalizedSDE: 0, category: .other)
        XCTAssertEqual(r.askedMultiple, .infinity)
        XCTAssertEqual(r.verdict, .priceyOutlier)
    }

    func testRevenueBasedIndustryUsesRevenue() {
        // Dental comps on revenue. $1M ask ÷ $1.2M revenue = 0.83x revenue (not ÷ SDE).
        let r = MultipleEngine.read(askingPrice: 1_000_000, normalizedSDE: 300_000, grossRevenue: 1_200_000, category: .dental)
        XCTAssertEqual(r.usedRevenueBasis, true)
        XCTAssertEqual(r.askedMultiple, 1_000_000.0 / 1_200_000.0, accuracy: 0.001)
        XCTAssertEqual(r.basisLabel, "revenue")
    }

    func testRevenueBasedFallsBackToSDEWhenRevenueMissing() {
        let r = MultipleEngine.read(askingPrice: 1_000_000, normalizedSDE: 400_000, grossRevenue: nil, category: .dental)
        XCTAssertEqual(r.usedRevenueBasis, false)
        XCTAssertEqual(r.askedMultiple, 2.5, accuracy: 0.001)   // 1M / 400k SDE
        XCTAssertEqual(r.basisLabel, "SDE")
    }
}
