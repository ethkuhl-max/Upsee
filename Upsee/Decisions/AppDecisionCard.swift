import SwiftUI

struct AppDecisionCard: View {
    let rec: AppDecisionRecommendation
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(rec.appName).font(.callout.weight(.semibold))
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rec.verdict.tint.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(rec.verdict.tint.opacity(0.18))
        )
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            stat("Revenue", currency(rec.monthlyRevenue))
            stat("Hours (30d)", String(format: "%.1fh", rec.hoursLogged))
            stat("$/hr", rec.hoursLogged > 0 ? currency(rec.revenuePerHour) : "—")
            if let days = rec.daysSinceLastShipped {
                stat("Shipped", "\(days)d ago")
            } else {
                stat("Shipped", "never")
            }
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

struct VerdictBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct SignalChip: View {
    let signal: AppDecisionSignal

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text("\(signal.label): \(signal.detail)").font(.caption2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
        .foregroundStyle(tint)
    }

    private var tint: Color {
        switch signal.polarity {
        case 1: return .green
        case -1: return .red
        default: return .secondary
        }
    }

    private var icon: String {
        switch signal.polarity {
        case 1: return "arrow.up"
        case -1: return "arrow.down"
        default: return "minus"
        }
    }
}

/// Minimal SwiftUI flow layout for chips. Pre-iOS-16 alternative would need GeometryReader;
/// macOS 26 / iOS 16+ Layout protocol gives us this for ~20 lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
