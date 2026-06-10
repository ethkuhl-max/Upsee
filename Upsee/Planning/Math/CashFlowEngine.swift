import Foundation

struct CashFlowPoint: Equatable, Identifiable {
    var id: Int { month }
    let month: Int
    let date: Date
    let income: Decimal
    let expenses: Decimal
    let netFlow: Decimal
    let cumulativeBalance: Decimal
}

struct CashFlowProjection: Equatable {
    let points: [CashFlowPoint]
    let startingBalance: Decimal
    let monthlyIncome: Decimal
    let monthlyExpenses: Decimal
    let monthlyNet: Decimal

    /// Months until balance hits zero — nil if cash-flow positive (never zero) or
    /// negative starting balance.
    var monthsToZero: Int? {
        let net = NSDecimalNumber(decimal: monthlyNet).doubleValue
        let balance = NSDecimalNumber(decimal: startingBalance).doubleValue
        guard net < 0, balance > 0 else { return nil }
        return Int(ceil(balance / -net))
    }
}

enum CashFlowEngine {
    /// Project monthly balance forward `monthsAhead` months at the supplied flat
    /// income/expense rate. Month 0 is the current balance; month N is the balance
    /// after N months of net flow.
    static func project(
        startingBalance: Decimal,
        monthlyIncome: Decimal,
        monthlyExpenses: Decimal,
        monthsAhead: Int = 12,
        startDate: Date = Date()
    ) -> CashFlowProjection {
        var points: [CashFlowPoint] = []
        var balance = startingBalance
        let cal = Calendar.current
        let net = monthlyIncome - monthlyExpenses

        for month in 0...monthsAhead {
            let date = cal.date(byAdding: .month, value: month, to: startDate) ?? startDate
            if month > 0 {
                balance += net
            }
            points.append(CashFlowPoint(
                month: month,
                date: date,
                income: monthlyIncome,
                expenses: monthlyExpenses,
                netFlow: net,
                cumulativeBalance: balance
            ))
        }
        return CashFlowProjection(
            points: points,
            startingBalance: startingBalance,
            monthlyIncome: monthlyIncome,
            monthlyExpenses: monthlyExpenses,
            monthlyNet: net
        )
    }

    /// Roll up monthly income across active jobs, all apps, and a personal "other income"
    /// line item on PersonalEntity.
    static func aggregateMonthlyIncome(
        jobs: [JobEntity],
        apps: [AppEntity],
        personal: PersonalEntity?
    ) -> Decimal {
        let jobIncome = jobs
            .filter { $0.status == .active }
            .reduce(Decimal(0)) { $0 + $1.monthlyCompensation }
        let appIncome = apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue }
        let personalIncome = personal?.monthlyIncome ?? 0
        return jobIncome + appIncome + personalIncome
    }

    static func aggregateMonthlyExpenses(personal: PersonalEntity?) -> Decimal {
        personal?.monthlyExpenses ?? 0
    }

    /// Project under scenario overrides — any nil override falls through to the base value.
    static func project(
        scenario: ScenarioEntity,
        baseStartingBalance: Decimal,
        baseIncome: Decimal,
        baseExpenses: Decimal
    ) -> CashFlowProjection {
        project(
            startingBalance: scenario.startingBalanceOverride ?? baseStartingBalance,
            monthlyIncome: scenario.monthlyIncomeOverride ?? baseIncome,
            monthlyExpenses: scenario.monthlyExpensesOverride ?? baseExpenses,
            monthsAhead: scenario.monthsAhead,
            startDate: scenario.startsAt
        )
    }

    /// Project applying per-entity overrides against the live entity lists. A global
    /// `monthlyIncomeOverride` still wins if set; otherwise income is rebuilt entity by entity.
    static func project(
        scenario: ScenarioEntity,
        jobs: [JobEntity],
        apps: [AppEntity],
        personal: PersonalEntity?,
        baseStartingBalance: Decimal,
        baseExpenses: Decimal
    ) -> CashFlowProjection {
        project(
            startingBalance: scenario.startingBalanceOverride ?? baseStartingBalance,
            monthlyIncome: resolvedMonthlyIncome(scenario: scenario, jobs: jobs, apps: apps, personal: personal),
            monthlyExpenses: scenario.monthlyExpensesOverride ?? baseExpenses,
            monthsAhead: scenario.monthsAhead,
            startDate: scenario.startsAt
        )
    }

    /// Monthly income for a scenario after applying per-entity overrides. A global income
    /// override short-circuits the entity walk.
    static func resolvedMonthlyIncome(
        scenario: ScenarioEntity,
        jobs: [JobEntity],
        apps: [AppEntity],
        personal: PersonalEntity?
    ) -> Decimal {
        if let global = scenario.monthlyIncomeOverride { return global }

        let overrides = scenario.entityOverrides
        func appOverride(_ name: String) -> ScenarioEntityOverride? {
            overrides.first { $0.kind == .app && $0.targetName == name }
        }
        func jobOverride(_ title: String) -> ScenarioEntityOverride? {
            overrides.first { $0.kind == .job && $0.targetName == title }
        }

        let appIncome = apps.reduce(Decimal(0)) { sum, app in
            if let o = appOverride(app.name) {
                return sum + (o.included ? (o.monthlyValueOverride ?? app.monthlyRevenue) : 0)
            }
            return sum + app.monthlyRevenue
        }
        let jobIncome = jobs.reduce(Decimal(0)) { sum, job in
            if let o = jobOverride(job.title) {
                // An override can include an otherwise-inactive job, or exclude an active one.
                return sum + (o.included ? (o.monthlyValueOverride ?? job.monthlyCompensation) : 0)
            }
            return sum + (job.status == .active ? job.monthlyCompensation : 0)
        }
        return appIncome + jobIncome + (personal?.monthlyIncome ?? 0)
    }
}
