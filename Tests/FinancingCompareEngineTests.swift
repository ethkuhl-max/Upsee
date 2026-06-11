import XCTest
@testable import Upsee

final class FinancingCompareEngineTests: XCTestCase {
    func testCashHasZeroFinanceCost() {
        let cash = FinancingOption(name: "Cash", kind: .cash, downPayment: 0, apr: 0, termMonths: 0, residual: 0, fixedMonthlyPayment: 0)
        let result = FinancingCompareEngine.compare(
            purchasePrice: 30_000,
            options: [cash],
            assumedReturn: 0.07,
            availableCash: 50_000
        )
        XCTAssertEqual(NSDecimalNumber(decimal: result[0].financeCost).doubleValue, 0)
    }

    func testLoanHasPositiveFinanceCost() {
        let loan = FinancingOption(name: "Loan", kind: .loan, downPayment: 5_000, apr: 0.06, termMonths: 60, residual: 0, fixedMonthlyPayment: 0)
        let result = FinancingCompareEngine.compare(
            purchasePrice: 30_000,
            options: [loan],
            assumedReturn: 0.07,
            availableCash: 50_000
        )
        XCTAssertGreaterThan(NSDecimalNumber(decimal: result[0].financeCost).doubleValue, 0)
    }

    func testOpportunityCostScalesWithCashUsed() {
        let cashHeavy = FinancingOption(name: "Cash heavy", kind: .cash, downPayment: 0, apr: 0, termMonths: 60, residual: 0, fixedMonthlyPayment: 0)
        let lowDown = FinancingOption(name: "Low down loan", kind: .loan, downPayment: 1_000, apr: 0.06, termMonths: 60, residual: 0, fixedMonthlyPayment: 0)
        let result = FinancingCompareEngine.compare(
            purchasePrice: 30_000,
            options: [cashHeavy, lowDown],
            assumedReturn: 0.07,
            availableCash: 50_000
        )
        // All-cash purchase incurs much more opportunity cost than $1k down loan.
        XCTAssertGreaterThan(
            NSDecimalNumber(decimal: result[0].opportunityCost).doubleValue,
            NSDecimalNumber(decimal: result[1].opportunityCost).doubleValue
        )
    }
}
