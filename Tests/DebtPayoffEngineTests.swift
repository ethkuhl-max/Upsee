import XCTest
@testable import Upsee

final class DebtPayoffEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    private func debt(_ name: String, _ balance: Decimal, _ apr: Double, _ min: Decimal) -> DebtInput {
        DebtInput(id: UUID(), name: name, balance: balance, apr: apr, minimumPayment: min)
    }

    func testSingleZeroInterestDebtPaysOffExactly() {
        let debts = [debt("Card", 1_200, 0.0, 100)]
        let r = DebtPayoffEngine.plan(debts: debts, strategy: .avalanche)
        XCTAssertEqual(r.monthsToDebtFree, 12)               // 1200 / 100
        XCTAssertEqual(d(r.totalInterestPaid), 0, accuracy: 0.01)
        XCTAssertEqual(r.payoffOrderNames, ["Card"])
    }

    func testInterestAccrues() {
        let debts = [debt("Card", 5_000, 0.24, 150)]
        let r = DebtPayoffEngine.plan(debts: debts, strategy: .avalanche)
        XCTAssertGreaterThan(d(r.totalInterestPaid), 0)
        XCTAssertNotNil(r.monthsToDebtFree)
    }

    func testAvalanchePrioritizesHighestAPR() {
        let high = debt("HighAPR", 2_000, 0.25, 50)
        let low = debt("LowAPR", 2_000, 0.05, 50)
        let r = DebtPayoffEngine.plan(debts: [low, high], strategy: .avalanche, extraMonthlyPayment: 300)
        XCTAssertEqual(r.payoffOrderNames.first, "HighAPR")
    }

    func testSnowballPrioritizesSmallestBalance() {
        let big = debt("Big", 8_000, 0.20, 100)
        let small = debt("Small", 1_000, 0.10, 50)
        let r = DebtPayoffEngine.plan(debts: [big, small], strategy: .snowball, extraMonthlyPayment: 300)
        XCTAssertEqual(r.payoffOrderNames.first, "Small")
    }

    func testExtraPaymentAcceleratesPayoff() {
        let debts = [debt("Loan", 10_000, 0.10, 200)]
        let base = DebtPayoffEngine.plan(debts: debts, strategy: .avalanche, extraMonthlyPayment: 0)
        let fast = DebtPayoffEngine.plan(debts: debts, strategy: .avalanche, extraMonthlyPayment: 300)
        XCTAssertNotNil(base.monthsToDebtFree)
        XCTAssertNotNil(fast.monthsToDebtFree)
        XCTAssertLessThan(fast.monthsToDebtFree!, base.monthsToDebtFree!)
        XCTAssertLessThan(d(fast.totalInterestPaid), d(base.totalInterestPaid))
    }

    func testAvalancheCostsLessInterestThanSnowball() {
        let a = debt("A", 3_000, 0.28, 60)
        let b = debt("B", 6_000, 0.06, 120)
        let avalanche = DebtPayoffEngine.plan(debts: [a, b], strategy: .avalanche, extraMonthlyPayment: 200)
        let snowball = DebtPayoffEngine.plan(debts: [a, b], strategy: .snowball, extraMonthlyPayment: 200)
        XCTAssertLessThanOrEqual(d(avalanche.totalInterestPaid), d(snowball.totalInterestPaid))
    }

    func testNoDebtIsZeroMonths() {
        let r = DebtPayoffEngine.plan(debts: [], strategy: .avalanche)
        XCTAssertEqual(r.monthsToDebtFree, 0)
        XCTAssertEqual(d(r.totalInterestPaid), 0)
    }
}
