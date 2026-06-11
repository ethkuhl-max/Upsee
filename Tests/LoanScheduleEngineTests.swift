import XCTest
@testable import Upsee

final class LoanScheduleEngineTests: XCTestCase {
    func testStandardPaymentForKnownLoan() {
        // $100,000 at 6% APR for 30 years should be ~$599.55/mo.
        let payment = LoanScheduleEngine.standardMonthlyPayment(principal: 100_000, apr: 0.06, termMonths: 360)
        XCTAssertEqual(NSDecimalNumber(decimal: payment).doubleValue, 599.55, accuracy: 0.05)
    }

    func testZeroAPRAmortizesEvenly() {
        let payment = LoanScheduleEngine.standardMonthlyPayment(principal: 12_000, apr: 0, termMonths: 12)
        XCTAssertEqual(NSDecimalNumber(decimal: payment).doubleValue, 1_000, accuracy: 0.01)
    }

    func testScheduleEndsAtZero() {
        let schedule = LoanScheduleEngine.schedule(
            principal: 10_000,
            apr: 0.05,
            termMonths: 24,
            monthlyPayment: 438.71
        )
        XCTAssertLessThan(NSDecimalNumber(decimal: schedule.lines.last?.endingBalance ?? 0).doubleValue, 1.0)
    }

    func testExtraPaymentShortensTerm() {
        let base = LoanScheduleEngine.schedule(
            principal: 100_000,
            apr: 0.06,
            termMonths: 360,
            monthlyPayment: 599.55
        )
        let withExtra = LoanScheduleEngine.schedule(
            principal: 100_000,
            apr: 0.06,
            termMonths: 360,
            monthlyPayment: 599.55,
            extraPayment: 200
        )
        XCTAssertLessThan(withExtra.lines.count, base.lines.count)
        XCTAssertGreaterThan(withExtra.monthsSaved, 0)
        XCTAssertGreaterThan(NSDecimalNumber(decimal: withExtra.interestSaved).doubleValue, 0)
    }

    func testInterestSumsRespectAPR() {
        // 12mo at 0% with $1000 principal → 0 interest.
        let zero = LoanScheduleEngine.schedule(principal: 1_000, apr: 0, termMonths: 12, monthlyPayment: 83.34)
        XCTAssertEqual(NSDecimalNumber(decimal: zero.totalInterest).doubleValue, 0, accuracy: 0.5)
    }
}
