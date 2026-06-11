import XCTest
@testable import Upsee

final class SubscriptionEngineTests: XCTestCase {
    private func tx(_ merchant: String, _ amount: Double, daysAgo: Int) -> Transaction {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Transaction(date: date, amount: Decimal(amount), merchant: merchant, accountName: "Chase")
    }

    func testDetectsMonthlyRecurringCharge() {
        let txs = [
            tx("Netflix", -15.99, daysAgo: 60),
            tx("Netflix", -15.99, daysAgo: 30),
            tx("Netflix", -15.99, daysAgo: 0),
        ]
        let subs = SubscriptionEngine.detect(transactions: txs)
        XCTAssertEqual(subs.count, 1)
        XCTAssertEqual(subs.first?.cadence, .monthly)
        XCTAssertEqual(NSDecimalNumber(decimal: subs.first?.monthlyEquivalent ?? 0).doubleValue, 15.99, accuracy: 0.01)
    }

    func testIgnoresOneOffCharges() {
        let txs = [tx("Apple Store", -1200, daysAgo: 30)]
        let subs = SubscriptionEngine.detect(transactions: txs)
        XCTAssertTrue(subs.isEmpty)
    }

    func testFlagsZombieWhenStale() {
        let txs = [
            tx("OldGym", -50, daysAgo: 200),
            tx("OldGym", -50, daysAgo: 170),
            tx("OldGym", -50, daysAgo: 140),
        ]
        let subs = SubscriptionEngine.detect(transactions: txs)
        XCTAssertEqual(subs.count, 1)
        XCTAssertTrue(subs.first?.likelyCancelled ?? false)
    }

    func testAnnualSubscriptionDetected() {
        let txs = [
            tx("Domain Registrar", -120, daysAgo: 365 * 2),
            tx("Domain Registrar", -120, daysAgo: 365),
            tx("Domain Registrar", -120, daysAgo: 0),
        ]
        let subs = SubscriptionEngine.detect(transactions: txs)
        XCTAssertEqual(subs.count, 1)
        XCTAssertEqual(subs.first?.cadence, .annual)
        XCTAssertEqual(NSDecimalNumber(decimal: subs.first?.monthlyEquivalent ?? 0).doubleValue, 10, accuracy: 0.01)
    }

    func testMonthlyBurnExcludesCancelled() {
        let txs = [
            tx("Netflix", -10, daysAgo: 60),
            tx("Netflix", -10, daysAgo: 30),
            tx("Netflix", -10, daysAgo: 0),
            tx("OldGym", -50, daysAgo: 200),
            tx("OldGym", -50, daysAgo: 170),
        ]
        let subs = SubscriptionEngine.detect(transactions: txs)
        let burn = SubscriptionEngine.monthlyBurn(subs)
        XCTAssertEqual(NSDecimalNumber(decimal: burn).doubleValue, 10, accuracy: 0.01)
    }
}
