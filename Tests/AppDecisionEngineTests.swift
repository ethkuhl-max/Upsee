import XCTest
@testable import Upsee

final class AppDecisionEngineTests: XCTestCase {
    private func entry(label: String, hoursAgo: Double, minutes: Int) -> TimeEntry {
        let date = Date().addingTimeInterval(-hoursAgo * 3600)
        return TimeEntry(startedAt: date, minutes: minutes, entityKind: "app", entityLabel: label)
    }

    func testKillsZeroRevenueZeroHoursStale() {
        let app = AppEntity(name: "Zombie", monthlyRevenue: 0)
        app.lastShippedAt = Calendar.current.date(byAdding: .day, value: -180, to: Date())
        let rec = AppDecisionEngine.recommend(app: app, timeEntries: [])
        XCTAssertEqual(rec.verdict, .kill)
    }

    func testDoubleDownStrongRevenueRecentShip() {
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 5_000)
        app.lastShippedAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        let entries = [entry(label: "Tmpo", hoursAgo: 24, minutes: 60)]
        let rec = AppDecisionEngine.recommend(app: app, timeEntries: entries)
        XCTAssertEqual(rec.verdict, .doubleDown)
    }

    func testRescueOnRecentActivityButNoRevenue() {
        let app = AppEntity(name: "Driver", monthlyRevenue: 0)
        app.lastShippedAt = Calendar.current.date(byAdding: .day, value: -20, to: Date())
        let entries = (1...3).map { entry(label: "Driver", hoursAgo: Double($0 * 24), minutes: 120) }
        let rec = AppDecisionEngine.recommend(app: app, timeEntries: entries)
        XCTAssertEqual(rec.verdict, .rescue)
    }

    func testHoldOnSmallButRealRevenue() {
        let app = AppEntity(name: "Side", monthlyRevenue: 50)
        app.lastShippedAt = Calendar.current.date(byAdding: .day, value: -45, to: Date())
        let entries = [entry(label: "Side", hoursAgo: 24, minutes: 30)]
        let rec = AppDecisionEngine.recommend(app: app, timeEntries: entries)
        XCTAssertTrue([.hold, .grow].contains(rec.verdict))
    }

    func testFiltersOtherAppsTime() {
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 0)
        let entries = [
            entry(label: "Tmpo", hoursAgo: 24, minutes: 60),
            entry(label: "Other", hoursAgo: 24, minutes: 600),
        ]
        let rec = AppDecisionEngine.recommend(app: app, timeEntries: entries)
        XCTAssertEqual(rec.hoursLogged, 1.0)
    }

    func testRevenuePerHourComputation() {
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 100)
        let entries = [entry(label: "Tmpo", hoursAgo: 24, minutes: 120)]
        let rec = AppDecisionEngine.recommend(app: app, timeEntries: entries)
        XCTAssertEqual(NSDecimalNumber(decimal: rec.revenuePerHour).doubleValue, 50.0, accuracy: 0.01)
    }
}
