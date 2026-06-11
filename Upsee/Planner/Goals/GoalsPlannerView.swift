import SwiftUI
import SwiftData

struct GoalsPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GoalEntity.priority) private var goals: [GoalEntity]
    @Query private var personal: [PersonalEntity]
    @State private var assumedReturn: Double = 0.05

    private var availableMonthlySavings: Decimal {
        guard let p = personal.first else { return 0 }
        return max(0, p.monthlyIncome - p.monthlyExpenses)
    }

    private var summary: GoalsBudgetSummary {
        GoalFundingEngine.plan(goals: goals, availableMonthlySavings: availableMonthlySavings, assumedReturn: assumedReturn)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            header
            if summary.hasShortfall { shortfallBanner }
            returnSlider
            goalsList
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Goals-based planning").font(.title3.weight(.semibold))
            Text("Each goal gets a target $ and target date. Engine computes required monthly contribution and allocates available savings by priority. Shortfall surfaces when total required exceeds savings.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            stat("Goals", "\(goals.filter { $0.status == .active }.count)")
            statAmount("Available savings", summary.availableMonthlySavings)
            statAmount("Total required", summary.totalRequiredMonthly,
                       tint: summary.hasShortfall ? .red : .primary)
            if summary.hasShortfall {
                statAmount("Shortfall", summary.shortfall, tint: .red)
            } else {
                statAmount("Surplus", max(0, summary.availableMonthlySavings - summary.totalRequiredMonthly), tint: .green)
            }
            Spacer()
        }
    }

    private var shortfallBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Goals exceed available savings").font(.callout.weight(.semibold))
                Text("Reorder priority, lower target amounts, push dates out, or earn/save more. Lower-priority goals are unfunded until shortfall clears.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.25)))
    }

    private var returnSlider: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ASSUMED RETURN").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Slider(value: $assumedReturn, in: 0.0...0.10, step: 0.005)
                Text(String(format: "%.1f%%", assumedReturn * 100)).font(.caption.monospacedDigit())
            }
            .frame(maxWidth: 280)
            Spacer()
        }
    }

    private var goalsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.plans.isEmpty {
                EmptyHint(text: "No active goals. Add one in the Planning section to start.")
            } else {
                ForEach(summary.plans) { plan in
                    GoalPlanRow(plan: plan)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func statAmount(_ label: String, _ amount: Decimal, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            SecureAmount(amount: amount, tint: tint, font: .title3.monospacedDigit().weight(.medium))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }
}

private struct GoalPlanRow: View {
    let plan: GoalFundingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: plan.goal.kind.systemImage).foregroundStyle(plan.goal.kind.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.goal.name).font(.callout.weight(.semibold))
                    Text("\(plan.goal.kind.displayName) · Priority \(plan.goal.priority)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if plan.isOnTrack {
                    Pill(text: "On track", tint: .green)
                } else {
                    Pill(text: "Underfunded", tint: .red)
                }
            }
            HStack(spacing: 16) {
                miniStat("Target", currency(plan.goal.targetAmount))
                miniStat("Current", currency(plan.goal.currentAmount))
                if let months = plan.monthsRemaining {
                    miniStat("Months left", "\(months)")
                }
                miniStat("Required/mo", currency(plan.requiredMonthlyContribution), tint: plan.isOnTrack ? .primary : .red)
                if plan.requiredMonthlyWithGrowth > 0 && plan.requiredMonthlyWithGrowth != plan.requiredMonthlyContribution {
                    miniStat("w/ growth", currency(plan.requiredMonthlyWithGrowth), tint: .green)
                }
                if let projected = plan.projectedHitMonths {
                    miniStat("At pace", "\(projected)mo")
                }
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.secondary.opacity(0.12))
                    Rectangle().fill(plan.goal.kind.tint.opacity(0.7))
                        .frame(width: geo.size.width * plan.goal.progress)
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(plan.goal.kind.tint.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(plan.goal.kind.tint.opacity(0.18)))
    }

    private func miniStat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(tint)
        }
    }
}
