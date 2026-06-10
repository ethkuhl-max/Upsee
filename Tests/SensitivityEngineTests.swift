import XCTest
@testable import Upsee

final class SensitivityEngineTests: XCTestCase {
    func testStressMatrixReturnsFourRows() {
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let rows = SensitivityEngine.stressMatrix(normalizedSDE: 400_000, loanTerms: loan)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].label, "Base case")
        XCTAssertEqual(rows[1].label, "Revenue −10%")
        XCTAssertEqual(rows[2].label, "Revenue −20%")
        XCTAssertEqual(rows[3].label, "Rate +100 bps")
    }

    func testRevenueStressLowersDSCR() {
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let rows = SensitivityEngine.stressMatrix(normalizedSDE: 400_000, loanTerms: loan)
        XCTAssertGreaterThan(rows[0].dscr.value, rows[1].dscr.value)
        XCTAssertGreaterThan(rows[1].dscr.value, rows[2].dscr.value)
    }

    func testRateStressLowersDSCR() {
        let loan = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let rows = SensitivityEngine.stressMatrix(normalizedSDE: 400_000, loanTerms: loan)
        XCTAssertGreaterThan(rows[0].dscr.value, rows[3].dscr.value)
    }
}
