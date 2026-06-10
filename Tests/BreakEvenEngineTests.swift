import XCTest
@testable import Upsee

final class BreakEvenEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    func testBreakEvenEqualsDebtService() {
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let be = BreakEvenEngine.analyze(normalizedSDE: 400_000, loan: loan)
        XCTAssertEqual(d(be.breakEvenSDE), d(be.annualDebtService), accuracy: 0.01)
    }

    func testLenderFloorIsHigherThanBreakEven() {
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let be = BreakEvenEngine.analyze(normalizedSDE: 400_000, loan: loan)
        XCTAssertEqual(d(be.lenderFloorSDE), d(be.annualDebtService) * 1.25, accuracy: 0.01)
        XCTAssertGreaterThan(be.sdeCushionToBreakEven, be.sdeCushionToLenderFloor)
    }

    func testBigSDEHasLargeCushion() {
        let loan = LoanTerms(principal: 100_000, annualRate: 0.10, amortizationYears: 10)
        let be = BreakEvenEngine.analyze(normalizedSDE: 1_000_000, loan: loan)
        XCTAssertGreaterThan(be.sdeCushionToBreakEven, 0.8)
    }

    func testScenarioStacksDebtService() {
        let sba = LoanTerms(principal: 800_000, annualRate: 0.115, amortizationYears: 10)
        let note = LoanTerms(principal: 200_000, annualRate: 0.07, amortizationYears: 5)
        let scenario = FinancingScenario(label: "stack", loans: [sba, note], buyerEquity: 0)
        let be = BreakEvenEngine.analyze(normalizedSDE: 400_000, scenario: scenario)
        let expected = d(LoanEngine.annualDebtService(scenario))
        XCTAssertEqual(d(be.annualDebtService), expected, accuracy: 0.01)
    }
}
