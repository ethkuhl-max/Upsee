import XCTest
@testable import Upsee

final class JobDecisionEngineTests: XCTestCase {
    func testTakeItWhenStrongRateAndCoverage() {
        let job = JobEntity(title: "Staff Eng", employer: "BigCo", monthlyCompensation: 20_000, hoursPerWeek: 20)
        let personal = PersonalEntity(monthlyIncome: 0, monthlyExpenses: 5_000)
        let rec = JobDecisionEngine.recommend(job: job, personal: personal, appsRevenue: 0)
        XCTAssertEqual(rec.verdict, .takeIt)
    }

    func testDeclineWhenUnderMarketAndHighHours() {
        let job = JobEntity(title: "Underpaid", employer: "TinyCo", monthlyCompensation: 1_500, hoursPerWeek: 60)
        let personal = PersonalEntity(monthlyIncome: 0, monthlyExpenses: 5_000)
        let rec = JobDecisionEngine.recommend(job: job, personal: personal, appsRevenue: 0)
        XCTAssertEqual(rec.verdict, .decline)
    }

    func testEffectiveHourlyRate() {
        let job = JobEntity(title: "Dev", employer: "Co", monthlyCompensation: 8_660, hoursPerWeek: 40)
        let personal = PersonalEntity()
        let rec = JobDecisionEngine.recommend(job: job, personal: personal, appsRevenue: 0)
        // ~$50/hr.
        XCTAssertEqual(NSDecimalNumber(decimal: rec.effectiveHourlyRate).doubleValue, 50, accuracy: 1)
    }

    func testRunwayCalculation() {
        let job = JobEntity(title: "Dev", employer: "Co", monthlyCompensation: 10_000, hoursPerWeek: 40)
        let personal = PersonalEntity(monthlyIncome: 0, monthlyExpenses: 5_000)
        let rec = JobDecisionEngine.recommend(job: job, personal: personal, appsRevenue: 0)
        // (10000 - 5000) / 5000 = 1.0
        XCTAssertEqual(rec.runwayMonthsAdded, 1.0, accuracy: 0.01)
    }
}
