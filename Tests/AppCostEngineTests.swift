import XCTest
@testable import Upsee

final class AppCostEngineTests: XCTestCase {
    func testMonthlyEquivalentForMonthlyCadence() {
        let c = AppCost(name: "RC", entityLabel: "Tmpo", amount: 50)
        XCTAssertEqual(c.monthlyEquivalent(), 50)
    }

    func testAnnualNormalizes() {
        let c = AppCost(name: "Dom", entityLabel: "Tmpo", amount: 120, cadence: .annual)
        XCTAssertEqual(c.monthlyEquivalent(), 10)
    }

    func testQuarterlyNormalizes() {
        let c = AppCost(name: "Q", entityLabel: "Tmpo", amount: 30, cadence: .quarterly)
        XCTAssertEqual(c.monthlyEquivalent(), 10)
    }

    func testOneTimeAmortizesOverYear() {
        let c = AppCost(
            name: "Design",
            entityLabel: "Tmpo",
            amount: 1_200,
            cadence: .oneTime,
            startedAt: Date()
        )
        // Within first year, amortizes to 100/mo.
        XCTAssertEqual(c.monthlyEquivalent(), 100)
    }

    func testEndedCostReturnsZero() {
        let past = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let c = AppCost(
            name: "Cancelled",
            entityLabel: "Tmpo",
            amount: 100,
            cadence: .monthly,
            startedAt: Calendar.current.date(byAdding: .month, value: -3, to: Date())!,
            endedAt: past
        )
        XCTAssertEqual(c.monthlyEquivalent(), 0)
    }

    func testProfitEngineSubtractsCosts() {
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 500)
        let costs = [
            AppCost(name: "RC", entityLabel: "Tmpo", amount: 50),
            AppCost(name: "Domain", entityLabel: "Tmpo", amount: 120, cadence: .annual),
        ]
        let prof = AppProfitEngine.summarize(app: app, costs: costs, hoursLogged: 10)
        XCTAssertEqual(prof.monthlyCosts, 60) // 50 + (120/12)
        XCTAssertEqual(prof.netMonthlyProfit, 440)
        XCTAssertEqual(prof.netMargin, 440.0 / 500.0, accuracy: 0.001)
    }

    func testNetRevenuePerHour() {
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 500)
        let costs = [AppCost(name: "RC", entityLabel: "Tmpo", amount: 100)]
        let prof = AppProfitEngine.summarize(app: app, costs: costs, hoursLogged: 4)
        // (500 - 100) / 4 = 100
        XCTAssertEqual(NSDecimalNumber(decimal: prof.netRevenuePerHour).doubleValue, 100, accuracy: 0.001)
    }

    func testIgnoresCostsForOtherApps() {
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 500)
        let costs = [
            AppCost(name: "RC", entityLabel: "Tmpo", amount: 50),
            AppCost(name: "RC", entityLabel: "Driver", amount: 50),
        ]
        let prof = AppProfitEngine.summarize(app: app, costs: costs, hoursLogged: 10)
        XCTAssertEqual(prof.monthlyCosts, 50)
    }
}
