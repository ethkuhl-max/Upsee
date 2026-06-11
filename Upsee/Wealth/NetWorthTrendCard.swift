import SwiftUI
import SwiftData
import Charts

struct NetWorthTrendCard: View {
    let snapshots: [NetWorthSnapshot]
    let currentSummary: NetWorthSummary

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if snapshots.isEmpty {
            EmptyHint(text: "No snapshots yet. Take your first to start the trend line.")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                chart
                statsRow
                recentList
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(snapshots) { snap in
                AreaMark(
                    x: .value("Date", snap.date),
                    y: .value("Net Worth", NSDecimalNumber(decimal: snap.netWorth).doubleValue)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Date", snap.date),
                    y: .value("Net Worth", NSDecimalNumber(decimal: snap.netWorth).doubleValue)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(
                    x: .value("Date", snap.date),
                    y: .value("Net Worth", NSDecimalNumber(decimal: snap.netWorth).doubleValue)
                )
                .foregroundStyle(Color.accentColor)
                .symbolSize(60)
            }
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 220)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(formatAxisCurrency(d))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            stat("First", currency(snapshots.first?.netWorth ?? 0))
            stat("Latest", currency(snapshots.last?.netWorth ?? 0))
            if snapshots.count > 1, let first = snapshots.first, let last = snapshots.last {
                let delta = last.netWorth - first.netWorth
                let pctNum = NSDecimalNumber(decimal: delta).doubleValue
                let denomNum = NSDecimalNumber(decimal: first.netWorth).doubleValue
                let pct = denomNum != 0 ? (pctNum / abs(denomNum) * 100) : 0
                stat("Δ", currency(delta), tint: delta >= 0 ? .green : .red)
                stat("Δ%", String(format: "%+.1f%%", pct), tint: delta >= 0 ? .green : .red)
            }
            Spacer()
        }
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent snapshots").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(snapshots.reversed().prefix(5)) { snap in
                HStack {
                    Text(snap.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text(currency(snap.netWorth))
                        .font(.callout.monospacedDigit().weight(.medium))
                    Spacer()
                    if !snap.note.isEmpty {
                        Text(snap.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Button(role: .destructive) {
                        modelContext.delete(snap)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }

    private func formatAxisCurrency(_ d: Double) -> String {
        let abs = Swift.abs(d)
        let sign = d < 0 ? "-" : ""
        if abs >= 1_000_000 { return "\(sign)$\(Int(abs / 1_000_000))M" }
        if abs >= 1_000 { return "\(sign)$\(Int(abs / 1_000))K" }
        return "\(sign)$\(Int(abs))"
    }
}

struct AddSnapshotSheet: View {
    let items: [BalanceSheetItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Take Net Worth Snapshot").font(.title3.weight(.semibold))
            Text("Captures totals + per-category breakdown from your current balance sheet.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                DatePicker("As of", selection: $date, displayedComponents: [.date])
                VStack(alignment: .leading, spacing: 4) {
                    Text("Note").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("Optional", text: $note).textFieldStyle(.roundedBorder)
                }
                let preview = NetWorthSnapshot.capture(from: items, date: date)
                HStack(spacing: 14) {
                    previewStat("Assets", currency(preview.totalAssets))
                    previewStat("Liabilities", currency(preview.totalLiabilities))
                    previewStat("Net worth", currency(preview.netWorth), tint: preview.netWorth >= 0 ? .primary : .red)
                }
            }

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Capture") {
                    let snap = NetWorthSnapshot.capture(from: items, date: date, note: note)
                    modelContext.insert(snap)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func previewStat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }
}
