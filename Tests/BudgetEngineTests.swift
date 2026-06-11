import XCTest
@testable import Upsee

final class BudgetEngineTests: XCTestCase {
    private func tx(_ amount: Double, category: TxCategory, daysAgo: Int) -> Transaction {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Transaction(date: date, amount: Decimal(amount), merchant: "X", accountName: "A", category: category)
    }

    func testOnTrackUnderEightyPercent() {
        let budgets = [Budget(category: .food, monthlyTarget: 1000)]
        let txs = [tx(-500, category: .food, daysAgo: 1)]
        let s = BudgetEngine.summarize(budgets: budgets, transactions: txs)
        XCTAssertEqual(s.lines.first?.status, .onTrack)
    }

    func testApproachingBetween80And100() {
        let budgets = [Budget(category: .food, monthlyTarget: 1000)]
        let txs = [tx(-900, category: .food, daysAgo: 1)]
        let s = BudgetEngine.summarize(budgets: budgets, transactions: txs)
        XCTAssertEqual(s.lines.first?.status, .approaching)
    }

    func testOverWhenExceeded() {
        let budgets = [Budget(category: .food, monthlyTarget: 500)]
        let txs = [tx(-700, category: .food, daysAgo: 1)]
        let s = BudgetEngine.summarize(budgets: budgets, transactions: txs)
        XCTAssertEqual(s.lines.first?.status, .over)
        XCTAssertEqual(s.overCategories.count, 1)
    }

    func testIgnoresIncomeTransactions() {
        let budgets = [Budget(category: .food, monthlyTarget: 500)]
        let txs = [tx(5000, category: .income, daysAgo: 1)]
        let s = BudgetEngine.summarize(budgets: budgets, transactions: txs)
        XCTAssertEqual(s.lines.first?.actual, 0)
    }

    func testUnbudgetedCategorySurfacedAsSuggestion() {
        let txs = [tx(-200, category: .entertainment, daysAgo: 1)]
        let s = BudgetEngine.summarize(budgets: [], transactions: txs)
        XCTAssertEqual(s.underNoBudget.count, 1)
        XCTAssertEqual(s.underNoBudget.first?.category, .entertainment)
    }
}
