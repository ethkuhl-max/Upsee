import SwiftUI

struct DealDecisionCard: View {
    let rec: DealDecisionRecommendation
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(rec.businessName).font(.callout.weight(.semibold))
                VerdictBadge(text: rec.verdict.displayName, tint: rec.verdict.tint)
                Spacer()
                Button("Log decision", action: onLog).buttonStyle(.bordered).controlSize(.small)
            }
            if let headline = rec.analysisHeadline {
                Text(headline)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
            if let dispo = rec.analysisDisposition {
                Text("Analysis verdict: \(dispo)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            signalsRow
            Text(rec.reasoning).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(rec.verdict.tint.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(rec.verdict.tint.opacity(0.18)))
    }

    private var signalsRow: some View {
        FlowLayout(spacing: 6) {
            ForEach(rec.signals) { signal in
                SignalChip(signal: signal)
            }
        }
    }
}
