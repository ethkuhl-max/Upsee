import Foundation

struct GoalFundingPlan: Identifiable {
    let id: UUID
    let goal: GoalEntity
    /// Months until target date. nil if no date set.
    let monthsRemaining: Int?
    /// Required monthly contribution to hit target by date (no return assumed).
    let requiredMonthlyContribution: Decimal
    /// Required monthly contribution assuming `assumedReturn` annual growth.
    let requiredMonthlyWithGrowth: Decimal
    /// True if requiredMonthlyContribution is funded by current monthlySavings allocation.
    let isOnTrack: Bool
    /// Months you'd hit the goal at the current allocation. nil if no allocation.
    let projectedHitMonths: Int?
}

struct GoalsBudgetSummary {
    let plans: [GoalFundingPlan]
    /// Sum of required monthly contributions across all active goals.
    let totalRequiredMonthly: Decimal
    /// Available monthly savings (from PersonalEntity).
    let availableMonthlySavings: Decimal
    /// Shortfall when totalRequired > available.
    let shortfall: Decimal
    /// True when totalRequiredMonthly > availableMonthlySavings — surfaces a hard alert.
    var hasShortfall: Bool { shortfall > 0 }
}

/// Computes per-goal required monthly contribution + portfolio-level shortfall.
enum GoalFundingEngine {
    static func plan(
        goals: [GoalEntity],
        availableMonthlySavings: Decimal,
        assumedReturn: Double = 0.05,
        now: Date = Date()
    ) -> GoalsBudgetSummary {
        let active = goals.filter { $0.status == .active }
        let plans = active.map { build(goal: $0, assumedReturn: assumedReturn, now: now) }
        let totalRequired = plans.reduce(Decimal(0)) { $0 + $1.requiredMonthlyContribution }
        let shortfall = max(0, totalRequired - availableMonthlySavings)
        // Determine on-track flags now that we know the available pool.
        let allocated = allocateAvailable(plans: plans, available: availableMonthlySavings)
        let plansWithOnTrack = zip(plans, allocated).map { (plan, alloc) -> GoalFundingPlan in
            GoalFundingPlan(
                id: plan.id,
                goal: plan.goal,
                monthsRemaining: plan.monthsRemaining,
                requiredMonthlyContribution: plan.requiredMonthlyContribution,
                requiredMonthlyWithGrowth: plan.requiredMonthlyWithGrowth,
                isOnTrack: alloc >= plan.requiredMonthlyContribution,
                projectedHitMonths: projectedMonths(
                    goal: plan.goal,
                    monthly: alloc,
                    assumedReturn: assumedReturn
                )
            )
        }
        return GoalsBudgetSummary(
            plans: plansWithOnTrack,
            totalRequiredMonthly: totalRequired,
            availableMonthlySavings: availableMonthlySavings,
            shortfall: shortfall
        )
    }

    private static func build(goal: GoalEntity, assumedReturn: Double, now: Date) -> GoalFundingPlan {
        let remaining = NSDecimalNumber(decimal: goal.remaining).doubleValue
        let months: Int? = {
            guard let target = goal.targetDate else { return nil }
            return max(1, Calendar.current.dateComponents([.month], from: now, to: target).month ?? 0)
        }()
        let required: Decimal = {
            guard let m = months, m > 0 else { return 0 }
            return Decimal(remaining / Double(m))
        }()
        let requiredWithGrowth: Decimal = {
            guard let m = months, m > 0 else { return 0 }
            let monthlyR = assumedReturn / 12.0
            guard monthlyR > 0 else { return Decimal(remaining / Double(m)) }
            // PMT for future value: PMT = FV * r / ((1+r)^n - 1)
            let n = Double(m)
            let pmt = remaining * monthlyR / (pow(1 + monthlyR, n) - 1)
            return Decimal(pmt)
        }()
        return GoalFundingPlan(
            id: UUID(),
            goal: goal,
            monthsRemaining: months,
            requiredMonthlyContribution: required,
            requiredMonthlyWithGrowth: requiredWithGrowth,
            isOnTrack: false,
            projectedHitMonths: nil
        )
    }

    /// Pro-rata allocate `available` monthly savings to plans by priority + required.
    /// Plans with higher priority (lower priority int) fund first.
    private static func allocateAvailable(plans: [GoalFundingPlan], available: Decimal) -> [Decimal] {
        var remaining = available
        let sortedIndices = plans.indices.sorted { plans[$0].goal.priority < plans[$1].goal.priority }
        var alloc = Array(repeating: Decimal(0), count: plans.count)
        for idx in sortedIndices {
            let need = plans[idx].requiredMonthlyContribution
            let give = min(need, remaining)
            alloc[idx] = give
            remaining -= give
            if remaining <= 0 { break }
        }
        return alloc
    }

    private static func projectedMonths(goal: GoalEntity, monthly: Decimal, assumedReturn: Double) -> Int? {
        let remaining = NSDecimalNumber(decimal: goal.remaining).doubleValue
        let pmt = NSDecimalNumber(decimal: monthly).doubleValue
        guard pmt > 0 else { return nil }
        let monthlyR = assumedReturn / 12.0
        if monthlyR <= 0 { return Int(ceil(remaining / pmt)) }
        // Months to reach future value = log(1 + FV*r/PMT) / log(1+r)
        let inner = 1 + remaining * monthlyR / pmt
        guard inner > 0 else { return nil }
        let months = log(inner) / log(1 + monthlyR)
        return Int(ceil(months))
    }
}
