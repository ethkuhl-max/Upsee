import SwiftUI

struct JobDecisionCard: View {
    let rec: JobDecisionRecommendation
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.jobTitle).font(.callout.weight(.semibold))
                    Text(rec.employer).font(.caption).foregroundStyle(.secondary)
                }
                VerdictBadge(text: rec.verdict.displayName, tint: rec.verdict.tint)
                Spacer()
                Button("Log decision", action: onLog).buttonStyle(.bordered).controlSize(.small)
            }
            statsRow
            signalsRow
            Text(rec.reasoning).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(rec.verdict.tint.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(rec.verdict.tint.opacity(0.18)))
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            stat("Hourly", currency(rec.effectiveHourlyRate))
            stat("Hrs/wk", "\(rec.opportunityCost)")
            stat("Runway", String(format: "%.1fx", rec.runwayMonthsAdded))
            Spacer()
        }
    }

    private var signalsRow: some View {
        FlowLayout(spacing: 6) {
            ForEach(rec.signals) { signal in
                SignalChip(signal: signal)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit())
        }
    }
}
