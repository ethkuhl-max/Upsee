import XCTest
@testable import Upsee

final class BurnoutEngineTests: XCTestCase {
    func testHealthyProfileIsLowRisk() {
        let entries = Array(repeating: WellbeingSample(energy: 4, stress: 2, sleepHours: 8, exerciseMinutes: 45), count: 5)
        let a = BurnoutEngine.assess(entries: entries, weeklyWorkHours: 40)
        XCTAssertEqual(a.band, .low)
        XCTAssertLessThan(a.score, 25)
        XCTAssertTrue(a.drivers.isEmpty)
    }

    func testOverworkedProfileIsHighRisk() {
        let entries = Array(repeating: WellbeingSample(energy: 1, stress: 5, sleepHours: 5, exerciseMinutes: 0), count: 5)
        let a = BurnoutEngine.assess(entries: entries, weeklyWorkHours: 75)
        XCTAssertEqual(a.band, .high)
        XCTAssertGreaterThan(a.score, 70)
        XCTAssertTrue(a.drivers.contains { $0.contains("stress") })
    }

    func testNoEntriesUsesHoursOnly() {
        let lowHours = BurnoutEngine.assess(entries: [], weeklyWorkHours: 40)
        let highHours = BurnoutEngine.assess(entries: [], weeklyWorkHours: 80)
        XCTAssertLessThan(lowHours.score, highHours.score)
    }

    func testMoreHoursRaisesRisk() {
        let entries = [WellbeingSample(energy: 3, stress: 3, sleepHours: 7, exerciseMinutes: 20)]
        let calm = BurnoutEngine.assess(entries: entries, weeklyWorkHours: 40)
        let grind = BurnoutEngine.assess(entries: entries, weeklyWorkHours: 70)
        XCTAssertGreaterThan(grind.score, calm.score)
    }
}
