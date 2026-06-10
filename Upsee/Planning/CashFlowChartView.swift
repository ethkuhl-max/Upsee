import SwiftUI
import Charts

struct CashFlowChartView: View {
    let projection: CashFlowProjection

    private var points: [CashFlowPoint] { projection.points }

    private var minBalance: Double {
        points.map { NSDecimalNumber(decimal: $0.cumulativeBalance).doubleValue }.min() ?? 0
    }

    private var maxBalance: Double {
        points.map { NSDecimalNumber(decimal: $0.cumulativeBalance).doubleValue }.max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Month", point.date),
                        y: .value("Balance", NSDecimalNumber(decimal: point.cumulativeBalance).doubleValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.45), .accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Balance", NSDecimalNumber(decimal: point.cumulativeBalance).doubleValue)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("$0")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: 260)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let double = value.as(Double.self) {
                            Text(formatAxisCurrency(double))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                }
            }

            footerStats
        }
    }

    private var footerStats: some View {
        HStack(spacing: 24) {
            FooterStat(label: "Start", value: currency(projection.startingBalance))
            FooterStat(label: "End", value: currency(points.last?.cumulativeBalance ?? 0))
            FooterStat(label: "Min", value: formatBalanceLabel(minBalance))
            FooterStat(label: "Max", value: formatBalanceLabel(maxBalance))
        }
    }

    private func formatBalanceLabel(_ d: Double) -> String {
        currency(Decimal(d))
    }

    private func formatAxisCurrency(_ d: Double) -> String {
        let abs = Swift.abs(d)
        let sign = d < 0 ? "-" : ""
        if abs >= 1_000_000 {
            return "\(sign)$\(Int(abs / 1_000_000))M"
        } else if abs >= 1_000 {
            return "\(sign)$\(Int(abs / 1_000))K"
        }
        return "\(sign)$\(Int(abs))"
    }
}

private struct FooterStat: View {
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
