import XCTest
@testable import Upsee

final class CashFlowEngineTests: XCTestCase {
    func testProjectionReturnsCorrectNumberOfPoints() {
        let p = CashFlowEngine.project(
            startingBalance: 10_000,
            monthlyIncome: 5_000,
            monthlyExpenses: 4_000,
            monthsAhead: 12
        )
        XCTAssertEqual(p.points.count, 13)
        XCTAssertEqual(p.points.first?.month, 0)
        XCTAssertEqual(p.points.last?.month, 12)
    }

    func testStartingBalanceIsMonthZero() {
        let p = CashFlowEngine.project(
            startingBalance: 25_000,
            monthlyIncome: 0,
            monthlyExpenses: 0,
            monthsAhead: 3
        )
        XCTAssertEqual(p.points.first?.cumulativeBalance, 25_000)
    }

    func testPositiveNetCompoundsForward() {
        let p = CashFlowEngine.project(
            startingBalance: 10_000,
            monthlyIncome: 5_000,
            monthlyExpenses: 4_000,
            monthsAhead: 12
        )
        XCTAssertEqual(p.points.last?.cumulativeBalance, 22_000)
    }

    func testNegativeNetDrainsBalance() {
        let p = CashFlowEngine.project(
            startingBalance: 10_000,
            monthlyIncome: 2_000,
            monthlyExpenses: 3_000,
            monthsAhead: 6
        )
        XCTAssertEqual(p.points.last?.cumulativeBalance, 4_000)
    }

    func testMonthsToZeroForBurningPersonalBalance() {
        let p = CashFlowEngine.project(
            startingBalance: 12_000,
            monthlyIncome: 3_000,
            monthlyExpenses: 5_000,
            monthsAhead: 24
        )
        XCTAssertEqual(p.monthsToZero, 6)
    }

    func testMonthsToZeroIsNilWhenCashFlowPositive() {
        let p = CashFlowEngine.project(
            startingBalance: 12_000,
            monthlyIncome: 5_000,
            monthlyExpenses: 4_000,
            monthsAhead: 24
        )
        XCTAssertNil(p.monthsToZero)
    }

    func testAggregateIncomeOnlyCountsActiveJobs() {
        let active = JobEntity(title: "Day Job", employer: "X", status: .active, monthlyCompensation: 8_000)
        let pending = JobEntity(title: "Future", employer: "Y", status: .pending, monthlyCompensation: 9_000)
        let app = AppEntity(name: "Weather.Co", monthlyRevenue: 500)
        let personal = PersonalEntity(monthlyIncome: 100)

        let total = CashFlowEngine.aggregateMonthlyIncome(jobs: [active, pending], apps: [app], personal: personal)
        XCTAssertEqual(total, 8_600)
    }

    func testScenarioOverrideIncomeOnly() {
        let scenario = ScenarioEntity(
            name: "Quit job",
            monthlyIncomeOverride: 1_500,
            monthsAhead: 12
        )
        let p = CashFlowEngine.project(
            scenario: scenario,
            baseStartingBalance: 50_000,
            baseIncome: 8_000,
            baseExpenses: 4_000
        )
        XCTAssertEqual(p.monthlyIncome, 1_500)
        XCTAssertEqual(p.monthlyExpenses, 4_000)
        XCTAssertEqual(p.monthlyNet, -2_500)
        XCTAssertEqual(p.points.last?.cumulativeBalance, 50_000 - (2_500 * 12))
    }

    func testPerEntityOverrideExcludesJobAndBumpsApp() {
        let job = JobEntity(title: "Day Job", employer: "X", status: .active, monthlyCompensation: 8_000)
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 500)
        let personal = PersonalEntity(monthlyIncome: 100)

        let scenario = ScenarioEntity(name: "Quit & grow app")
        scenario.entityOverrides = [
            .init(kind: .job, targetName: "Day Job", included: false),
            .init(kind: .app, targetName: "Tmpo", included: true, monthlyValueOverride: 5_000),
        ]

        let income = CashFlowEngine.resolvedMonthlyIncome(scenario: scenario, jobs: [job], apps: [app], personal: personal)
        // Job removed (0) + app overridden to 5_000 + personal 100.
        XCTAssertEqual(income, 5_100)
    }

    func testGlobalIncomeOverrideWinsOverPerEntity() {
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 500)
        let scenario = ScenarioEntity(name: "Flat", monthlyIncomeOverride: 9_000)
        scenario.entityOverrides = [.init(kind: .app, targetName: "Tmpo", included: false)]

        let income = CashFlowEngine.resolvedMonthlyIncome(scenario: scenario, jobs: [], apps: [app], personal: nil)
        XCTAssertEqual(income, 9_000)
    }

    func testNoOverridesMatchesBaseAggregate() {
        let job = JobEntity(title: "Day Job", employer: "X", status: .active, monthlyCompensation: 8_000)
        let app = AppEntity(name: "Tmpo", monthlyRevenue: 500)
        let personal = PersonalEntity(monthlyIncome: 100)
        let scenario = ScenarioEntity(name: "Baseline")

        let income = CashFlowEngine.resolvedMonthlyIncome(scenario: scenario, jobs: [job], apps: [app], personal: personal)
        let base = CashFlowEngine.aggregateMonthlyIncome(jobs: [job], apps: [app], personal: personal)
        XCTAssertEqual(income, base)
    }
}
