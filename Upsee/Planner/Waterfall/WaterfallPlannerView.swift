import SwiftUI
import SwiftData
import Charts

struct WaterfallPlannerView: View {
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]
    @Query private var transactions: [Transaction]

    @State private var startIdx: Int = 0
    @State private var endIdx: Int = 0

    private var validRange: Bool {
        snapshots.count >= 2 && startIdx < endIdx && endIdx < snapshots.count
    }

    private var waterfall: NetWorthWaterfall? {
        guard validRange else { return nil }
        return NetWorthWaterfallEngine.decompose(
            from: snapshots[startIdx],
            to: snapshots[endIdx],
            transactions: transactions
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            if snapshots.count < 2 {
                EmptyHint(text: "Capture at least 2 net worth snapshots in Wealth → Net Worth Trend to decompose the change.")
            } else {
                rangePickers
                if let w = waterfall {
                    waterfallStats(w)
                    waterfallChart(w)
                    attribution(w)
                }
            }
        }
        .onAppear {
            if snapshots.count >= 2 {
                startIdx = 0
                endIdx = snapshots.count - 1
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Net worth waterfall").font(.title3.weight(.semibold))
            Text("Between two snapshots, decompose the change into income, spending, contributions, and market return. Answers \"did I save my way there or did the market do it?\"")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var rangePickers: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FROM").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Picker("From", selection: $startIdx) {
                    ForEach(0..<snapshots.count, id: \.self) { idx in
                        Text(snapshots[idx].date.formatted(date: .abbreviated, time: .omitted)).tag(idx)
                    }
                }
                .pickerStyle(.menu).labelsHidden()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("TO").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Picker("To", selection: $endIdx) {
                    ForEach(0..<snapshots.count, id: \.self) { idx in
                        Text(snapshots[idx].date.formatted(date: .abbreviated, time: .omitted)).tag(idx)
                    }
                }
                .pickerStyle(.menu).labelsHidden()
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private func waterfallStats(_ w: NetWorthWaterfall) -> some View {
        HStack(spacing: 14) {
            statAmount("Start", w.startNetWorth)
            statAmount("End", w.endNetWorth)
            statAmount("Delta", w.delta, tint: w.delta >= 0 ? .green : .red)
            stat("Saved share", String(format: "%.0f%%", w.savedShare * 100), tint: .blue)
            stat("Market share", String(format: "%.0f%%", w.marketShare * 100), tint: .green)
            Spacer()
        }
    }

    private func waterfallChart(_ w: NetWorthWaterfall) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONTRIBUTION TO DELTA").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Chart {
                ForEach(w.steps) { step in
                    if step.kind == .start || step.kind == .end {
                        BarMark(
                            x: .value("Step", step.label),
                            y: .value("Amount", NSDecimalNumber(decimal: step.amount).doubleValue)
                        )
                        .foregroundStyle(Color.secondary.opacity(0.6))
                    } else {
                        BarMark(
                            x: .value("Step", step.label),
                            y: .value("Amount", NSDecimalNumber(decimal: step.amount).doubleValue)
                        )
                        .foregroundStyle(tint(step.kind))
                    }
                }
            }
            .frame(height: 240)
        }
    }

    private func attribution(_ w: NetWorthWaterfall) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ATTRIBUTION").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(w.steps.filter { $0.kind != .start && $0.kind != .end }) { step in
                HStack(spacing: 10) {
                    Circle().fill(tint(step.kind)).frame(width: 10, height: 10)
                    Text(step.label).font(.callout)
                    Spacer()
                    SecureAmount(amount: step.amount,
                                 tint: step.amount >= 0 ? .green : .red,
                                 font: .callout.monospacedDigit())
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(tint(step.kind).opacity(0.08)))
            }
        }
    }

    private func tint(_ kind: WaterfallKind) -> Color {
        switch kind {
        case .start, .end: return .secondary
        case .income: return .green
        case .spending: return .red
        case .contributions: return .blue
        case .marketReturn: return .purple
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
