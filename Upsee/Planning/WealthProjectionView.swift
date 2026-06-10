import SwiftUI
import Charts

/// Interactive long-horizon wealth projection: deterministic compounding plus a
/// Monte Carlo distribution of outcomes and a financial-independence timeline.
struct WealthProjectionView: View {
    let startingBalance: Decimal
    let defaultMonthlyContribution: Decimal

    @State private var monthlyContribution: Double = 0
    @State private var annualReturn: Double = 0.07
    @State private var volatility: Double = 0.15
    @State private var years: Int = 20
    @State private var fiTarget: Double = 1_000_000
    @State private var didSeed = false

    private struct YearlyValue: Identifiable {
        let year: Int
        let value: Double
        var id: Int { year }
    }

    private var projection: WealthProjection {
        WealthEngine.project(
            startingBalance: startingBalance,
            monthlyContribution: Decimal(monthlyContribution),
            annualReturn: annualReturn,
            years: years
        )
    }

    private var monteCarlo: MonteCarloResult {
        WealthEngine.monteCarlo(
            startingBalance: startingBalance,
            monthlyContribution: Decimal(monthlyContribution),
            annualReturnMean: annualReturn,
            annualReturnStdDev: volatility,
            years: years,
            target: Decimal(fiTarget),
            paths: 400
        )
    }

    private var fiYears: Double? {
        WealthEngine.yearsToTarget(
            startingBalance: startingBalance,
            monthlyContribution: Decimal(monthlyContribution),
            annualReturn: annualReturn,
            target: Decimal(fiTarget)
        )
    }

    private var deterministicYearly: [YearlyValue] {
        projection.points
            .filter { $0.month % 12 == 0 && $0.month > 0 }
            .map { YearlyValue(year: $0.month / 12, value: dbl($0.balance)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controls
            chart
            headlineMetrics
        }
        .onAppear {
            guard !didSeed else { return }
            didSeed = true
            monthlyContribution = max(0, dbl(defaultMonthlyContribution))
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            sliderRow("Monthly invest", value: currency(Decimal(monthlyContribution))) {
                Slider(value: $monthlyContribution, in: 0...20_000, step: 250)
            }
            sliderRow("Expected return", value: String(format: "%.1f%%", annualReturn * 100)) {
                Slider(value: $annualReturn, in: 0...0.15, step: 0.005)
            }
            sliderRow("Volatility", value: String(format: "%.0f%%", volatility * 100)) {
                Slider(value: $volatility, in: 0...0.30, step: 0.01)
            }
            sliderRow("FI target", value: shortCurrency(fiTarget)) {
                Slider(value: $fiTarget, in: 250_000...5_000_000, step: 250_000)
            }
            LabeledContent("Horizon") {
                Picker("Horizon", selection: $years) {
                    ForEach([10, 20, 30, 40], id: \.self) { y in
                        Text("\(y) yr").tag(y)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
    }

    private var chart: some View {
        let mc = monteCarlo
        return Chart {
            ForEach(mc.perYear, id: \.year) { yr in
                AreaMark(
                    x: .value("Year", yr.year),
                    yStart: .value("p10", dbl(yr.p10)),
                    yEnd: .value("p90", dbl(yr.p90))
                )
                .foregroundStyle(Color.accentColor.opacity(0.14))
                LineMark(
                    x: .value("Year", yr.year),
                    y: .value("Median", dbl(yr.p50)),
                    series: .value("Series", "Median")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            ForEach(deterministicYearly) { p in
                LineMark(
                    x: .value("Year", p.year),
                    y: .value("Expected", p.value),
                    series: .value("Series", "Expected")
                )
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            RuleMark(y: .value("Target", fiTarget))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("FI target").font(.caption2).foregroundStyle(.secondary)
                }
        }
        .frame(height: 240)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(shortCurrency(d)).font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: years <= 20 ? 5 : 10)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let y = value.as(Int.self) {
                        Text("Y\(y)").font(.caption)
                    }
                }
            }
        }
    }

    private var headlineMetrics: some View {
        let mc = monteCarlo
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                metric("Expected (\(years)yr)", currency(projection.endingBalance), tint: .green)
                metric("Median outcome", currency(mc.endingP50))
                metric("Downside (p10)", currency(mc.endingP10), tint: .orange)
                metric("Upside (p90)", currency(mc.endingP90), tint: .blue)
            }
            HStack(spacing: 14) {
                metric("Contributed", currency(projection.totalContributed))
                metric("Growth", currency(projection.totalGrowth))
                metric(
                    "Reach FI",
                    fiYears.map { $0 <= Double(years) ? String(format: "%.1f yr", $0) : "Beyond horizon" } ?? "Not on track",
                    tint: (fiYears.map { $0 <= Double(years) } ?? false) ? .green : .orange
                )
                metric(
                    "P(hit target)",
                    String(format: "%.0f%%", mc.probabilityAboveTarget * 100),
                    tint: mc.probabilityAboveTarget >= 0.7 ? .green : (mc.probabilityAboveTarget >= 0.4 ? .orange : .red)
                )
            }
        }
    }

    // MARK: - Helpers

    private func sliderRow<S: View>(_ label: String, value: String, @ViewBuilder _ slider: () -> S) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.callout)
                .frame(width: 120, alignment: .leading)
            slider()
            Text(value)
                .font(.callout.monospacedDigit())
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func metric(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func shortCurrency(_ d: Double) -> String {
        let abs = Swift.abs(d)
        if abs >= 1_000_000 { return "$\(String(format: "%.1f", d / 1_000_000))M" }
        if abs >= 1_000 { return "$\(Int(d / 1_000))K" }
        return "$\(Int(d))"
    }

    private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}
