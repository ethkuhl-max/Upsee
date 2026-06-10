import SwiftUI

// MARK: - App card

struct AppEntityCard: View {
    let entity: AppEntity

    var body: some View {
        EntityCardShell(
            title: entity.name,
            statusLabel: entity.status.displayName,
            statusTint: entity.status.tint
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if !entity.summary.isEmpty {
                    Text(entity.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 16) {
                    MetricView(label: "MRR", value: currency(entity.monthlyRevenue))
                    MetricView(label: "Users", value: "\(entity.activeUsers)")
                    if let shipped = entity.lastShippedAt {
                        MetricView(label: "Shipped", value: relative(shipped))
                    }
                }
                if entity.inFlightCount > 0 || entity.nextTargetVersion != nil || !entity.roadmap.isEmpty {
                    HStack(spacing: 12) {
                        if entity.inFlightCount > 0 {
                            inlineStat(symbol: "circle.bottomhalf.filled", text: "\(entity.inFlightCount) in flight", tint: .orange)
                        }
                        if let next = entity.nextTargetVersion {
                            inlineStat(symbol: "shippingbox", text: "Next: v\(next)", tint: .blue)
                        }
                        if entity.activeGoalCount > 0 {
                            inlineStat(symbol: "target", text: "\(entity.activeGoalCount) goal\(entity.activeGoalCount == 1 ? "" : "s")", tint: .purple)
                        }
                    }
                }
                if !entity.marketingNote.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "megaphone")
                            .foregroundStyle(.secondary)
                        Text(entity.marketingNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inlineStat(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2).foregroundStyle(tint)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Job card

struct JobEntityCard: View {
    let entity: JobEntity

    var body: some View {
        EntityCardShell(
            title: entity.title,
            statusLabel: entity.status.displayName,
            statusTint: entity.status.tint
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(entity.employer)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    MetricView(label: "Monthly", value: currency(entity.monthlyCompensation))
                    MetricView(label: "Hrs/wk", value: "\(entity.hoursPerWeek)")
                    if let start = entity.startDate {
                        MetricView(label: "Started", value: relative(start))
                    }
                }
                if !entity.note.isEmpty {
                    Text(entity.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Deal card

struct DealEntityCard: View {
    let entity: DealEntity

    var body: some View {
        EntityCardShell(
            title: entity.businessName,
            statusLabel: entity.status.displayName,
            statusTint: entity.status.tint
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if !entity.lastVerdictHeadline.isEmpty {
                    Text(entity.lastVerdictHeadline)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
                HStack(spacing: 16) {
                    MetricView(label: "Asking", value: currency(entity.askingPrice))
                    MetricView(label: "SDE", value: currency(entity.reportedSDE))
                }
                if let followUp = entity.followUpDate {
                    HStack(spacing: 4) {
                        Image(systemName: "bell")
                        Text("Follow up " + relative(followUp))
                    }
                    .font(.caption2)
                    .foregroundStyle(followUp < Date() ? .red : .orange)
                }
                if let analyzed = entity.lastAnalyzedAt {
                    Text("Analyzed " + relative(analyzed))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Personal card

struct PersonalEntityCard: View {
    let entity: PersonalEntity

    var body: some View {
        EntityCardShell(
            title: "Personal",
            statusLabel: runwayLabel,
            statusTint: runwayTint
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    MetricView(label: "Income", value: currency(entity.monthlyIncome))
                    MetricView(label: "Expenses", value: currency(entity.monthlyExpenses))
                }
                HStack(spacing: 16) {
                    MetricView(label: "Savings", value: currency(entity.currentSavings))
                    MetricView(label: "Burn/mo", value: currency(entity.monthlyBurn))
                }
                if !entity.note.isEmpty {
                    Text(entity.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var runwayLabel: String {
        let r = entity.runwayMonths
        if r.isInfinite { return "Cash-flow positive" }
        if r >= 12 { return String(format: "%.0fmo runway", r) }
        if r >= 6 { return String(format: "%.0fmo runway", r) }
        if r >= 3 { return String(format: "%.1fmo runway", r) }
        return "Short runway"
    }

    private var runwayTint: Color {
        let r = entity.runwayMonths
        if r.isInfinite { return .green }
        if r >= 12 { return .green }
        if r >= 6 { return .blue }
        if r >= 3 { return .orange }
        return .red
    }
}

// MARK: - Shared shell

struct EntityCardShell<Body: View>: View {
    let title: String
    let statusLabel: String
    let statusTint: Color
    @ViewBuilder var content: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Pill(text: statusLabel, tint: statusTint)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

struct Pill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
        }
    }
}

func currency(_ d: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    formatter.currencyCode = "USD"
    return formatter.string(from: NSDecimalNumber(decimal: d)) ?? "$0"
}

func relative(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}
