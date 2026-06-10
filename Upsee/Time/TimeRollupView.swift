import SwiftUI

struct TimeRollupView: View {
    let entries: [TimeEntry]
    let apps: [AppEntity]

    private var weekRollup: [Rollup] {
        rollup(window: weekWindow)
    }

    private var monthRollup: [Rollup] {
        rollup(window: monthWindow)
    }

    private var weekWindow: DateInterval {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -7, to: now) ?? now
        return DateInterval(start: start, end: now)
    }

    private var monthWindow: DateInterval {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -30, to: now) ?? now
        return DateInterval(start: start, end: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Where the week went")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Last 7 days")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if weekRollup.isEmpty {
                EmptyHint(text: "No time logged in the last 7 days.")
            } else {
                weekChart
            }

            if !monthRollup.isEmpty {
                Divider().padding(.vertical, 4)
                roiTable
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
    }

    private var weekChart: some View {
        let total = weekRollup.reduce(0) { $0 + $1.minutes }
        return VStack(spacing: 10) {
            ForEach(weekRollup) { row in
                let frac = total > 0 ? Double(row.minutes) / Double(total) : 0
                HStack(spacing: 10) {
                    Text(row.label)
                        .font(.callout.weight(.medium))
                        .frame(width: 140, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.12))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tint(for: row.kind))
                                .frame(width: max(2, geo.size.width * frac))
                        }
                    }
                    .frame(height: 16)
                    Text(formatHours(row.minutes))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            HStack {
                Spacer()
                Text("Total: \(formatHours(total))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var roiTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App ROI — revenue per logged hour (last 30 days)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(roiRows) { roi in
                HStack {
                    Text(roi.label)
                        .font(.callout.weight(.medium))
                        .frame(width: 140, alignment: .leading)
                    Text(formatHours(roi.minutes))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    Text(formatMonthlyRevenue(roi.monthlyRevenue))
                        .font(.callout.monospacedDigit())
                        .frame(width: 100, alignment: .trailing)
                    Text(formatROI(roi))
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(roi.isOpportunityCost ? .red : .primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var roiRows: [ROIRow] {
        let monthRoll = monthRollup.filter { $0.kind == "app" }
        return monthRoll.map { row in
            let app = apps.first { $0.name == row.label }
            let monthlyRevenue = app?.monthlyRevenue ?? 0
            return ROIRow(
                label: row.label,
                kind: row.kind,
                minutes: row.minutes,
                monthlyRevenue: monthlyRevenue
            )
        }
    }

    private func rollup(window: DateInterval) -> [Rollup] {
        let inWindow = entries.filter { window.contains($0.startedAt) }
        let grouped = Dictionary(grouping: inWindow) { "\($0.entityKind)/\($0.entityLabel)" }
        let rolls: [Rollup] = grouped.compactMap { key, group in
            guard let entry = group.first else { return nil }
            let minutes = group.reduce(0) { $0 + $1.minutes }
            return Rollup(id: key, kind: entry.entityKind, label: entry.entityLabel, minutes: minutes)
        }
        return rolls.sorted { $0.minutes > $1.minutes }
    }

    private func tint(for kind: String) -> Color {
        switch kind {
        case "app": return .blue
        case "job": return .orange
        case "deal": return .purple
        case "personal": return .green
        default: return .secondary
        }
    }

    private func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func formatMonthlyRevenue(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencyCode = "USD"
        return f.string(from: NSDecimalNumber(decimal: d)) ?? "$0"
    }

    private func formatROI(_ row: ROIRow) -> String {
        guard row.minutes > 0 else { return "—" }
        let hours = Double(row.minutes) / 60.0
        let revenue = NSDecimalNumber(decimal: row.monthlyRevenue).doubleValue
        guard hours > 0 else { return "—" }
        if revenue == 0 {
            return row.minutes > 0 ? "$0 / hr" : "—"
        }
        let perHour = revenue / hours
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencyCode = "USD"
        return (f.string(from: NSNumber(value: perHour)) ?? "$0") + " / hr"
    }
}

private struct Rollup: Identifiable {
    let id: String
    let kind: String
    let label: String
    let minutes: Int
}

private struct ROIRow: Identifiable {
    let label: String
    let kind: String
    let minutes: Int
    let monthlyRevenue: Decimal
    var id: String { "\(kind)/\(label)" }
    var isOpportunityCost: Bool {
        minutes > 0 && monthlyRevenue == 0
    }
}
