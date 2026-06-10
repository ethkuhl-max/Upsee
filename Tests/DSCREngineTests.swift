import XCTest
@testable import Upsee

final class DSCREngineTests: XCTestCase {
    func testDSCRForHealthyDeal() {
        // $500k SDE against ~$168k annual debt service (loan above) → ~2.96 DSCR
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let r = DSCREngine.dscr(normalizedSDE: 500_000, loan: loan)
        XCTAssertGreaterThan(r.value, 2.5)
        XCTAssertEqual(r.reading, .healthy)
    }

    func testDSCRForUnderwaterDeal() {
        // SDE barely covers debt service
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let r = DSCREngine.dscr(normalizedSDE: 150_000, loan: loan)
        XCTAssertLessThan(r.value, 1.15)
        XCTAssertEqual(r.reading, .underwater)
    }

    func testDSCRReadingBoundaries() {
        XCTAssertEqual(DSCRReading(1.50), .healthy)
        XCTAssertEqual(DSCRReading(1.40), .healthy)
        XCTAssertEqual(DSCRReading(1.30), .adequate)
        XCTAssertEqual(DSCRReading(1.25), .adequate)
        XCTAssertEqual(DSCRReading(1.20), .marginal)
        XCTAssertEqual(DSCRReading(1.15), .marginal)
        XCTAssertEqual(DSCRReading(1.10), .underwater)
    }

    func testMaxOfferRoundtrip() {
        // Compute max offer at DSCR 1.25, then DSCR at that offer should equal 1.25.
        let sde: Decimal = 300_000
        let target = 1.25
        let maxOffer = DSCREngine.maxOfferAt(
            targetDSCR: target,
            normalizedSDE: sde,
            rate: 0.115,
            amortizationYears: 10
        )
        let loan = LoanTerms(principal: maxOffer, annualRate: 0.115, amortizationYears: 10)
        let r = DSCREngine.dscr(normalizedSDE: sde, loan: loan)
        XCTAssertEqual(r.value, target, accuracy: 0.01)
    }

    func testMaxOfferIsLowerWhenTargetDSCRIsHigher() {
        let at125 = DSCREngine.maxOfferAt(targetDSCR: 1.25, normalizedSDE: 300_000, rate: 0.115, amortizationYears: 10)
        let at150 = DSCREngine.maxOfferAt(targetDSCR: 1.50, normalizedSDE: 300_000, rate: 0.115, amortizationYears: 10)
        XCTAssertGreaterThan(at125, at150)
    }

    func testScenarioDSCRStacksAllLoans() {
        let sba = LoanTerms(principal: 700_000, annualRate: 0.115, amortizationYears: 10)
        let seller = LoanTerms(principal: 200_000, annualRate: 0.07, amortizationYears: 5)
        let scenario = FinancingScenario(label: "Stack", loans: [sba, seller], buyerEquity: 100_000)
        let single = DSCREngine.dscr(normalizedSDE: 400_000, loan: sba)
        let stacked = DSCREngine.dscr(normalizedSDE: 400_000, scenario: scenario)
        XCTAssertLessThan(stacked.value, single.value, "Adding a seller note increases debt service and lowers DSCR")
    }
}
