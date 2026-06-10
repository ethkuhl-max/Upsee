import SwiftUI

struct ScenarioRow: View {
    let scenario: ScenarioEntity
    let jobs: [JobEntity]
    let apps: [AppEntity]
    let personal: PersonalEntity?
    let baseIncome: Decimal
    let baseExpenses: Decimal
    let baseBalance: Decimal

    private var resolvedIncome: Decimal {
        CashFlowEngine.resolvedMonthlyIncome(scenario: scenario, jobs: jobs, apps: apps, personal: personal)
    }

    private var projection: CashFlowProjection {
        CashFlowEngine.project(
            scenario: scenario,
            jobs: jobs,
            apps: apps,
            personal: personal,
            baseStartingBalance: baseBalance,
            baseExpenses: baseExpenses
        )
    }

    private var endingBalance: Decimal {
        projection.points.last?.cumulativeBalance ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(scenario.name).font(.callout.weight(.medium))
                Spacer()
                if scenario.entityOverrides.count > 0 {
                    Pill(text: "\(scenario.entityOverrides.count) entity", tint: .teal)
                }
                if !scenario.isBaseline {
                    Pill(text: "What-if", tint: .purple)
                } else {
                    Pill(text: "Baseline", tint: .blue)
                }
            }
            if !scenario.summary.isEmpty {
                Text(scenario.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                MetricView(label: "Income", value: currency(resolvedIncome))
                MetricView(label: "Expenses", value: currency(scenario.monthlyExpensesOverride ?? baseExpenses))
                MetricView(label: "Net/mo", value: currency(projection.monthlyNet))
                Spacer()
                MetricView(label: "End balance (\(scenario.monthsAhead)mo)", value: currency(endingBalance))
            }

            if let months = projection.monthsToZero {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Runs out in \(months) months under this scenario.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}
