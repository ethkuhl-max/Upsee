import SwiftUI

/// A "football field" valuation chart: the industry comp range (low → median → high,
/// applied to normalized SDE) with the asking price and the max supportable offer
/// plotted against it, so the buyer can see at a glance where the ask sits.
struct ValuationFootballFieldView: View {
    let analysis: Analysis

    /// The base the comp multiples apply to — gross revenue for revenue-based industries,
    /// otherwise normalized SDE.
    private var compBase: Double {
        dbl(analysis.multipleReading.denominator ?? analysis.normalized.normalized)
    }
    private var basisLabel: String { analysis.multipleReading.basisLabel }
    private var range: IndustryMultipleRange { analysis.multipleReading.industryRange }

    private var compLow: Double { range.low * compBase }
    private var compMedian: Double { range.median * compBase }
    private var compHigh: Double { range.high * compBase }
    private var asking: Double { dbl(analysis.deal.askingPrice) }
    private var maxOffer: Double { dbl(analysis.maxOffer) }

    private var domainMin: Double { max(0, [compLow, asking, maxOffer].min() ?? 0) * 0.92 }
    private var domainMax: Double { ([compHigh, asking, maxOffer].max() ?? 1) * 1.06 }

    private var askingTint: Color {
        switch analysis.multipleReading.verdict {
        case .underMedian: return .green
        case .atMedian: return .blue
        case .aboveMedian: return .orange
        case .priceyOutlier: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Valuation range")
                .font(.title3.weight(.semibold))

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    // Baseline track
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 14)
                        .offset(y: 40)

                    // Comp range band
                    let lowX = x(compLow, width)
                    let highX = x(compHigh, width)
                    Capsule()
                        .fill(Color.accentColor.opacity(0.30))
                        .frame(width: max(highX - lowX, 2), height: 14)
                        .offset(x: lowX, y: 40)

                    // Median tick
                    marker(label: "Median", sublabel: String(format: "%.1fx", range.median),
                           x: x(compMedian, width), color: .accentColor, above: false, height: 14)

                    // Asking
                    marker(label: "Asking", sublabel: currency(Decimal(asking)),
                           x: x(asking, width), color: askingTint, above: true, height: 30)

                    // Max offer
                    marker(label: "Max offer", sublabel: currency(Decimal(maxOffer)),
                           x: x(maxOffer, width), color: .teal, above: false, height: 30)
                }
            }
            .frame(height: 110)

            HStack {
                Text("Low " + String(format: "%.1fx · ", range.low) + currency(Decimal(compLow)))
                Spacer()
                Text(currency(Decimal(compHigh)) + String(format: " · %.1fx high", range.high))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                legend("Comp range", .accentColor.opacity(0.5))
                legend("Asking", askingTint)
                legend("Max offer", .teal)
            }
            if let note = range.note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Text("Comp multiples applied to \(basisLabel) (\(currency(Decimal(compBase)))).")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func x(_ value: Double, _ width: Double) -> Double {
        guard domainMax > domainMin else { return 0 }
        let fraction = (value - domainMin) / (domainMax - domainMin)
        return min(max(fraction, 0), 1) * width
    }

    private func marker(label: String, sublabel: String, x: Double, color: Color, above: Bool, height: Double) -> some View {
        VStack(spacing: 2) {
            if above {
                labelStack(label, sublabel, color)
                bar(color, height)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                bar(color, height)
                labelStack(label, sublabel, color)
            }
        }
        .frame(width: 90, height: 110)
        .offset(x: x - 45, y: 0)
    }

    private func bar(_ color: Color, _ height: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3, height: height + 14)
            .offset(y: 33 - height / 2)
    }

    private func labelStack(_ label: String, _ sublabel: String, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(color)
            Text(sublabel).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .fixedSize()
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}
