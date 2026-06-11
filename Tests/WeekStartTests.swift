import XCTest
@testable import Upsee

final class WeekStartTests: XCTestCase {
    func testMondayMapsToItself() {
        // 2026-06-08 is a Monday.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 8
        let cal = Calendar(identifier: .gregorian)
        let monday = cal.date(from: comps)!
        let result = WeekStart.of(monday)
        let resultComps = cal.dateComponents([.year, .month, .day], from: result)
        XCTAssertEqual(resultComps.year, 2026)
        XCTAssertEqual(resultComps.month, 6)
        XCTAssertEqual(resultComps.day, 8)
    }

    func testWednesdayMapsToMonday() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 10 // Wednesday
        let cal = Calendar(identifier: .gregorian)
        let wednesday = cal.date(from: comps)!
        let result = WeekStart.of(wednesday)
        let resultComps = cal.dateComponents([.year, .month, .day], from: result)
        XCTAssertEqual(resultComps.day, 8)
    }
}
