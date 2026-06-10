import XCTest
@testable import Upsee

final class TaxEstimatorTests: XCTestCase {
    func testNextQuarterlyDueDateIsNonNil() {
        XCTAssertNotNil(TaxEstimator.nextQuarterlyDueDate(from: Date()))
    }

    func testNextDueDateIsInTheFuture() {
        let now = Date()
        let due = TaxEstimator.nextQuarterlyDueDate(from: now)
        XCTAssertNotNil(due)
        XCTAssertGreaterThanOrEqual(due!, now)
    }

    func testPicksAprilFifteenthEarlyInYear() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 2; comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        let feb = cal.date(from: comps)!
        let due = TaxEstimator.nextQuarterlyDueDate(from: feb)!
        let dueComps = cal.dateComponents([.month, .day], from: due)
        XCTAssertEqual(dueComps.month, 4)
        XCTAssertEqual(dueComps.day, 15)
    }
}
