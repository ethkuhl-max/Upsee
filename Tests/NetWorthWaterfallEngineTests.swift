import XCTest
@testable import Upsee

final class NetWorthWaterfallEngineTests: XCTestCase {
    private func snap(_ amount: Double, daysAgo: Int) -> NetWorthSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let s = NetWorthSnapshot(date: date, totalAssets: Decimal(amount), totalLiabilities: 0)
        return s
    }

    private func tx(_ amount: Double, category: TxCategory, daysAgo: Int) -> Transaction {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Transaction(date: date, amount: Decimal(amount), merchant: "X", accountName: "A", category: category)
    }

    func testDeltaMatchesSnapshotDifference() {
        let start = snap(100_000, daysAgo: 60)
        let end = snap(120_000, daysAgo: 0)
        let w = NetWorthWaterfallEngine.decompose(from: start, to: end, transactions: [])
        XCTAssertEqual(NSDecimalNumber(decimal: w.delta).doubleValue, 20_000, accuracy: 1)
    }

    func testIncomeShowsInWaterfall() {
        let start = snap(100_000, daysAgo: 30)
        let end = snap(105_000, daysAgo: 0)
        let income = tx(10_000, category: .income, daysAgo: 10)
        let spending = tx(-5_000, category: .food, daysAgo: 5)
        let w = NetWorthWaterfallEngine.decompose(from: start, to: end, transactions: [income, spending])
        let incomeStep = w.steps.first { $0.kind == .income }!
        XCTAssertEqual(NSDecimalNumber(decimal: incomeStep.amount).doubleValue, 10_000, accuracy: 1)
    }

    func testTransfersIgnoredFromSpending() {
        let start = snap(100_000, daysAgo: 30)
        let end = snap(100_000, daysAgo: 0)
        let transfer = tx(-5_000, category: .transfer, daysAgo: 10)
        let w = NetWorthWaterfallEngine.decompose(from: start, to: end, transactions: [transfer])
        let spendingStep = w.steps.first { $0.kind == .spending }!
        XCTAssertEqual(NSDecimalNumber(decimal: spendingStep.amount).doubleValue, 0, accuracy: 1)
    }
}
