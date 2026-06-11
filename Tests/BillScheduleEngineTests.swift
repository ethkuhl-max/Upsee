import XCTest
@testable import Upsee

final class BillScheduleEngineTests: XCTestCase {
    private func bill(_ name: String, amount: Double, due daysFromNow: Int, cadence: BillCadence = .monthly) -> Bill {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return Bill(name: name, amount: Decimal(amount), nextDueDate: date, cadence: cadence)
    }

    func testEmptyHasZeroCommitted() {
        let summary = BillScheduleEngine.summarize([])
        XCTAssertEqual(summary.monthlyCommitted, 0)
        XCTAssertTrue(summary.occurrences.isEmpty)
    }

    func testMonthlyCommittedNormalizesCadence() {
        let bills = [
            bill("Rent", amount: 2000, due: 5, cadence: .monthly),
            bill("Domain", amount: 120, due: 5, cadence: .annual),     // → 10/mo
        ]
        let summary = BillScheduleEngine.summarize(bills)
        XCTAssertEqual(NSDecimalNumber(decimal: summary.monthlyCommitted).doubleValue, 2010, accuracy: 0.01)
    }

    func testDueThisWeekFiltering() {
        let bills = [
            bill("Soon", amount: 50, due: 3),
            bill("Later", amount: 50, due: 20),
        ]
        let summary = BillScheduleEngine.summarize(bills)
        let names = summary.dueThisWeek.map { $0.bill.name }
        XCTAssertTrue(names.contains("Soon"))
        XCTAssertFalse(names.contains("Later"))
    }

    func testOverdueFlagsPastDates() {
        let bills = [bill("Late", amount: 100, due: -5)]
        let summary = BillScheduleEngine.summarize(bills)
        XCTAssertEqual(summary.overdue.count, 1)
    }
}
