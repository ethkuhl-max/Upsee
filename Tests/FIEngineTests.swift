import XCTest
@testable import Upsee

final class FIEngineTests: XCTestCase {
    func testFINumberIsTwentyFiveTimesExpenses() {
        let s = FIEngine.summarize(annualExpenses: 40_000, netWorth: 0, annualSavings: 0)
        XCTAssertEqual(NSDecimalNumber(decimal: s.fiNumber).doubleValue, 1_000_000, accuracy: 1)
    }

    func testProgressBelowOne() {
        let s = FIEngine.summarize(annualExpenses: 40_000, netWorth: 500_000, annualSavings: 0)
        XCTAssertEqual(s.progress, 0.5, accuracy: 0.001)
    }

    func testAlreadyAtFI() {
        let s = FIEngine.summarize(annualExpenses: 40_000, netWorth: 1_000_000, annualSavings: 0)
        XCTAssertGreaterThanOrEqual(s.progress, 1.0)
        XCTAssertEqual(s.yearsToFI, 0)
    }

    func testYearsToFIIsFiniteForActiveSaver() {
        let s = FIEngine.summarize(annualExpenses: 40_000, netWorth: 100_000, annualSavings: 50_000)
        XCTAssertNotNil(s.yearsToFI)
        XCTAssertLessThan(s.yearsToFI ?? 999, 25)
    }

    func testCoverageMonthsReportsRunway() {
        let s = FIEngine.summarize(annualExpenses: 60_000, netWorth: 30_000, annualSavings: 0)
        // 30k / (60k/12) = 6 months.
        XCTAssertEqual(s.coverageMonths, 6, accuracy: 0.01)
    }

    func testZeroExpensesGracefullyHandled() {
        let s = FIEngine.summarize(annualExpenses: 0, netWorth: 100_000, annualSavings: 0)
        XCTAssertEqual(NSDecimalNumber(decimal: s.fiNumber).doubleValue, 0, accuracy: 0.01)
    }
}
