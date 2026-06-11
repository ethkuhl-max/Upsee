import XCTest
@testable import Upsee

final class GoalFundingEngineTests: XCTestCase {
    private func goal(_ name: String, target: Double, current: Double, monthsAhead: Int, priority: Int = 50) -> GoalEntity {
        let g = GoalEntity(
            name: name,
            targetAmount: Decimal(target),
            currentAmount: Decimal(current),
            targetDate: Calendar.current.date(byAdding: .month, value: monthsAhead, to: Date())
        )
        g.priority = priority
        return g
    }

    func testRequiredMonthlyMatchesArithmetic() {
        let g = goal("House", target: 100_000, current: 20_000, monthsAhead: 80)
        let summary = GoalFundingEngine.plan(goals: [g], availableMonthlySavings: 1_000, assumedReturn: 0)
        let plan = summary.plans.first!
        // Calendar month math is approximate; allow ±2% drift.
        XCTAssertEqual(NSDecimalNumber(decimal: plan.requiredMonthlyContribution).doubleValue, 1_000, accuracy: 25)
    }

    func testShortfallSurfacesWhenRequiredExceedsAvailable() {
        let g = goal("Quick", target: 10_000, current: 0, monthsAhead: 1)
        let summary = GoalFundingEngine.plan(goals: [g], availableMonthlySavings: 1_000)
        XCTAssertTrue(summary.hasShortfall)
        XCTAssertGreaterThan(NSDecimalNumber(decimal: summary.shortfall).doubleValue, 0)
    }

    func testHighPriorityFundsFirst() {
        let high = goal("Critical", target: 1_000, current: 0, monthsAhead: 1, priority: 10)
        let low = goal("Whenever", target: 1_000, current: 0, monthsAhead: 1, priority: 90)
        let summary = GoalFundingEngine.plan(goals: [high, low], availableMonthlySavings: 1_000)
        // High-priority should be on track, low should not.
        let highPlan = summary.plans.first { $0.goal.name == "Critical" }!
        let lowPlan = summary.plans.first { $0.goal.name == "Whenever" }!
        XCTAssertTrue(highPlan.isOnTrack)
        XCTAssertFalse(lowPlan.isOnTrack)
    }

    func testGrowthAssumptionReducesRequired() {
        let g = goal("Retire", target: 1_000_000, current: 0, monthsAhead: 360)
        let summary = GoalFundingEngine.plan(goals: [g], availableMonthlySavings: 5_000, assumedReturn: 0.07)
        let plan = summary.plans.first!
        // Required with growth should be much less than required without.
        XCTAssertLessThan(plan.requiredMonthlyWithGrowth, plan.requiredMonthlyContribution)
    }
}
