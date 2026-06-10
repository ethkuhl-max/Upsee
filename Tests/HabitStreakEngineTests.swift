import XCTest
@testable import Upsee

final class HabitStreakEngineTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private func key(_ daysAgo: Int, from today: Date) -> String {
        DayKey.string(from: cal.date(byAdding: .day, value: -daysAgo, to: today)!)
    }

    func testCurrentStreakCountsConsecutiveDaysIncludingToday() {
        let today = Date()
        let keys: Set<String> = [key(0, from: today), key(1, from: today), key(2, from: today)]
        let s = HabitStreakEngine.compute(completedDayKeys: keys, today: today)
        XCTAssertEqual(s.currentStreak, 3)
        XCTAssertTrue(s.doneToday)
    }

    func testStreakSurvivesWhenTodayNotYetDone() {
        let today = Date()
        // Done yesterday and the day before, not today.
        let keys: Set<String> = [key(1, from: today), key(2, from: today)]
        let s = HabitStreakEngine.compute(completedDayKeys: keys, today: today)
        XCTAssertEqual(s.currentStreak, 2)
        XCTAssertFalse(s.doneToday)
    }

    func testGapResetsCurrentStreak() {
        let today = Date()
        let keys: Set<String> = [key(0, from: today), key(2, from: today), key(3, from: today)]
        let s = HabitStreakEngine.compute(completedDayKeys: keys, today: today)
        XCTAssertEqual(s.currentStreak, 1)        // only today is consecutive
        XCTAssertEqual(s.longestStreak, 2)        // days 2 & 3 ago
    }

    func testCompletionRate() {
        let today = Date()
        let keys = Set((0..<15).map { key($0, from: today) })   // 15 of last 30
        let s = HabitStreakEngine.compute(completedDayKeys: keys, today: today)
        XCTAssertEqual(s.completionRate30, 0.5, accuracy: 0.0001)
    }

    func testEmptyIsZero() {
        let s = HabitStreakEngine.compute(completedDayKeys: [], today: Date())
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.longestStreak, 0)
        XCTAssertFalse(s.doneToday)
    }
}
