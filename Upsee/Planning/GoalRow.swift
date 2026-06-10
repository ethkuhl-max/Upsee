import SwiftUI

struct GoalRow: View {
    let goal: GoalEntity
    let monthlySavings: Decimal

    private var projected: Date? {
        goal.projectedHitDate(monthlySavings: monthlySavings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.name).font(.callout.weight(.medium))
                Spacer()
                Pill(text: goal.status.displayName, tint: goal.status.tint)
            }
            if !goal.summary.isEmpty {
                Text(goal.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: goal.progress)
                .tint(goal.status.tint)
            HStack {
                MetricView(label: "Current", value: currency(goal.currentAmount))
                Spacer()
                MetricView(label: "Target", value: currency(goal.targetAmount))
                Spacer()
                MetricView(label: "Projected", value: projectedLabel)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private var projectedLabel: String {
        if goal.status == .achieved { return "Done" }
        guard let date = projected else {
            if monthlySavings <= 0 { return "Not on track" }
            return "—"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}
