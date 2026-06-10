import SwiftUI
import Charts

struct MonteCarloProjectionCard: View {
    let startingBalance: Decimal
    let annualContribution: Decimal

    @Binding var years: Int
    @Binding var expectedReturn: Double
    @Binding var volatility: Double
    @Binding var target: String

    @State private var result: WealthMonteCarloResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            controls
            if let result {
                chart(for: result)
                stats(for: result)
            } else {
                EmptyHint(text: "Tap Run to simulate 1,000 paths. Volatility and expected return are inputs, not predictions.")
                    .onAppear { run() }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YEARS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Stepper("\(years) yr", value: $years, in: 3...60, step: 1)
                    .labelsHidden()
                Text("\(years) yr").font(.caption.monospacedDigit())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("EXPECTED RETURN").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Slider(value: $expectedReturn, in: 0.0...0.15, step: 0.005)
                Text(String(format: "%.1f%%", expectedReturn * 100))
                    .font(.caption.monospacedDigit())
            }
            .frame(maxWidth: 180)
            VStack(alignment: .leading, spacing: 2) {
                Text("VOLATILITY").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Slider(value: $volatility, in: 0.0...0.30, step: 0.01)
                Text(String(format: "%.1f%%", volatility * 100))
                    .font(.caption.monospacedDigit())
            }
            .frame(maxWidth: 180)
            VStack(alignment: .leading, spacing: 2) {
                Text("TARGET ($)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Optional", text: $target)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: 120)
            }
            Spacer()
            Button { run() } label: {
                Label("Run", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func chart(for result: WealthMonteCarloResult) -> some View {
        Chart {
            ForEach(result.points) { point in
                AreaMark(
                    x: .value("Year", point.date),
                    yStart: .value("p10", NSDecimalNumber(decimal: point.p10).doubleValue),
                    yEnd: .value("p90", NSDecimalNumber(decimal: point.p90).doubleValue)
                )
                .foregroundStyle(Color.accentColor.opacity(0.18))
                LineMark(
                    x: .value("Year", point.date),
                    y: .value("p50", NSDecimalNumber(decimal: point.p50).doubleValue),
                    series: .value("series", "Median")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                LineMark(
                    x: .value("Year", point.date),
                    y: .value("p10", NSDecimalNumber(decimal: point.p10).doubleValue),
                    series: .value("series", "p10")
                )
                .foregroundStyle(Color.orange.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                LineMark(
                    x: .value("Year", point.date),
                    y: .value("p90", NSDecimalNumber(decimal: point.p90).doubleValue),
                    series: .value("series", "p90")
                )
                .foregroundStyle(Color.green.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .frame(height: 240)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(formatAxisCurrency(d)).font(.caption.monospacedDigit())
                    }
                }
            }
        }
    }

    private func stats(for result: WealthMonteCarloResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 18) {
                stat("p10", currency(result.endingP10), tint: .orange)
                stat("Median", currency(result.endingMedian), tint: .primary)
                stat("p90", currency(result.endingP90), tint: .green)
                if let probability = result.probabilityOfTarget {
                    stat("Hit target", String(format: "%.0f%%", probability * 100), tint: probability >= 0.7 ? .green : .orange)
                }
                Spacer()
            }
            Text("Lognormal returns, \(result.paths) paths, contributions \(currency(annualContribution))/yr, starting \(currency(startingBalance)). Not a prediction — bands widen with volatility.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }

    private func run() {
        let targetDecimal: Decimal? = {
            let cleaned = target.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
            return Decimal(string: cleaned)
        }()
        result = MonteCarloEngine.project(
            startingBalance: startingBalance,
            annualContribution: annualContribution,
            yearsAhead: years,
            expectedReturn: expectedReturn,
            volatility: volatility,
            targetAmount: targetDecimal
        )
    }

    private func formatAxisCurrency(_ d: Double) -> String {
        let abs = Swift.abs(d)
        let sign = d < 0 ? "-" : ""
        if abs >= 1_000_000 { return "\(sign)$\(Int(abs / 1_000_000))M" }
        if abs >= 1_000 { return "\(sign)$\(Int(abs / 1_000))K" }
        return "\(sign)$\(Int(abs))"
    }
}
