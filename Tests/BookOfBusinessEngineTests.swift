import XCTest
@testable import Upsee

final class BookOfBusinessEngineTests: XCTestCase {
    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }
    private let cal = Calendar(identifier: .gregorian)

    private func client(_ name: String, _ aum: Decimal, _ fee: Double, _ status: ClientStatus, reviewInDays: Int? = nil, from today: Date) -> ClientBookInput {
        let date = reviewInDays.flatMap { cal.date(byAdding: .day, value: $0, to: today) }
        return ClientBookInput(name: name, aum: aum, feePercent: fee, status: status, nextReviewDate: date)
    }

    func testTotalsAndRevenue() {
        let today = Date()
        let clients = [
            client("A", 1_000_000, 0.01, .active, from: today),
            client("B", 500_000, 0.012, .active, from: today),
            client("C", 0, 0.01, .prospect, from: today),
        ]
        let s = BookOfBusinessEngine.summarize(clients, asOf: today)
        XCTAssertEqual(d(s.totalAUM), 1_500_000, accuracy: 0.01)
        XCTAssertEqual(d(s.annualRevenue), 1_000_000 * 0.01 + 500_000 * 0.012, accuracy: 0.01)
        XCTAssertEqual(s.activeCount, 2)
        XCTAssertEqual(s.prospectCount, 1)
    }

    func testWeightedFee() {
        let today = Date()
        let clients = [client("A", 1_000_000, 0.01, .active, from: today)]
        let s = BookOfBusinessEngine.summarize(clients, asOf: today)
        XCTAssertEqual(s.weightedAverageFee, 0.01, accuracy: 0.0001)
    }

    func testUpcomingReviewsIncludeOverdueAndWindow() {
        let today = Date()
        let clients = [
            client("Overdue", 100_000, 0.01, .active, reviewInDays: -10, from: today),
            client("Soon", 100_000, 0.01, .active, reviewInDays: 20, from: today),
            client("Later", 100_000, 0.01, .active, reviewInDays: 200, from: today),
            client("Inactive", 100_000, 0.01, .inactive, reviewInDays: 5, from: today),
        ]
        let s = BookOfBusinessEngine.summarize(clients, asOf: today, withinDays: 60)
        XCTAssertEqual(s.upcomingReviews.map(\.name), ["Overdue", "Soon"])  // sorted, window-filtered, inactive excluded
        XCTAssertTrue(s.upcomingReviews.first?.isOverdue == true)
    }

    func testEmptyBook() {
        let s = BookOfBusinessEngine.summarize([], asOf: Date())
        XCTAssertEqual(d(s.totalAUM), 0)
        XCTAssertEqual(s.weightedAverageFee, 0)
        XCTAssertTrue(s.upcomingReviews.isEmpty)
    }
}
