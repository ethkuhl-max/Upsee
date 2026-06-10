import XCTest
@testable import Upsee

final class AmortizationEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    func testPrincipalFullyAmortizes() {
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let sched = AmortizationEngine.schedule(for: loan)
        XCTAssertEqual(sched.months.count, 120)
        XCTAssertEqual(d(sched.months.last!.balance), 0, accuracy: 1.0)
        let totalPrincipal = sched.months.reduce(0.0) { $0 + d($1.principal) }
        XCTAssertEqual(totalPrincipal, 1_000_000, accuracy: 1.0)
        XCTAssertGreaterThan(d(sched.totalInterest), 0)
    }

    func testZeroInterestSchedule() {
        let loan = LoanTerms(principal: 120_000, annualRate: 0.0, amortizationYears: 10)
        let sched = AmortizationEngine.schedule(for: loan)
        XCTAssertEqual(d(sched.totalInterest), 0, accuracy: 0.01)
        XCTAssertEqual(d(sched.months.first!.principal), 1000, accuracy: 0.01)
    }

    func testYearsRollup() {
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.10, amortizationYears: 10)
        let sched = AmortizationEngine.schedule(for: loan)
        XCTAssertEqual(sched.years.count, 10)
        XCTAssertEqual(sched.years.last!.year, 10)
        XCTAssertEqual(d(sched.years.last!.endingBalance), 0, accuracy: 1.0)
    }

    func testScenarioCombinesLoans() {
        let sba = LoanTerms(principal: 800_000, annualRate: 0.115, amortizationYears: 10)
        let note = LoanTerms(principal: 200_000, annualRate: 0.07, amortizationYears: 5)
        let scenario = FinancingScenario(label: "stack", loans: [sba, note], buyerEquity: 100_000)
        let sched = AmortizationEngine.schedule(for: scenario)
        XCTAssertEqual(d(sched.totalPrincipal), 1_000_000, accuracy: 1.0)
        XCTAssertEqual(sched.months.count, 120) // max of 120 and 60
        // Debt service drops once the 5-year seller note is retired.
        let year3 = sched.years[2].interestPaid + sched.years[2].principalPaid
        let year7 = sched.years[6].interestPaid + sched.years[6].principalPaid
        XCTAssertGreaterThan(d(year3), d(year7))
    }

    func testEmptyScenarioIsSafe() {
        let scenario = FinancingScenario(label: "none", loans: [], buyerEquity: 0)
        let sched = AmortizationEngine.schedule(for: scenario)
        XCTAssertTrue(sched.months.isEmpty)
        XCTAssertEqual(d(sched.totalInterest), 0)
    }
}
