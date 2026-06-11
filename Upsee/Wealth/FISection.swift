import SwiftUI

struct FISection: View {
    let annualExpenses: Decimal
    let netWorth: Decimal
    let annualSavings: Decimal

    @State private var assumedReturn: Double = 0.07
    @State private var safeWithdrawalRate: Double = 0.04
    @Environment(LockManager.self) private var lockManager

    private var summary: FISummary {
        FIEngine.summarize(
            annualExpenses: annualExpenses,
            netWorth: netWorth,
            annualSavings: annualSavings,
            assumedReturn: assumedReturn,
            safeWithdrawalRate: safeWithdrawalRate
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerStats
            progressBar
            controls
            if annualExpenses == 0 {
                EmptyHint(text: "Set monthly expenses on Personal to compute your FI number — 25× annual expenses is the standard target.")
            } else {
                tiers
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 14) {
            stat("FI Number", summary.fiNumber, tint: .primary)
            stat("Net worth", summary.currentNetWorth)
            stat("Progress", Decimal(min(1, summary.progress)) * 100, tint: summary.progress >= 1 ? .green : .blue, showAsPercent: true)
            if let years = summary.yearsToFI {
                stat("Years to FI", Decimal(years), tint: years <= 10 ? .green : (years <= 25 ? .orange : .secondary), showAsYears: true)
            } else if summary.progress >= 1 {
                stat("Years to FI", Decimal(0), tint: .green, showAsYears: true)
            } else {
                statText("Years to FI", "—")
            }
            Spacer()
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Toward 25× expenses").font(.caption.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f%%", summary.progress * 100))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(summary.progress >= 1 ? Color.green : Color.blue)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.secondary.opacity(0.12))
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.green],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * min(1, summary.progress))
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EXPECTED RETURN").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Slider(value: $assumedReturn, in: 0.0...0.12, step: 0.005)
                Text(String(format: "%.1f%%", assumedReturn * 100)).font(.caption.monospacedDigit())
            }
            .frame(maxWidth: 240)

            VStack(alignment: .leading, spacing: 2) {
                Text("WITHDRAWAL RATE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Slider(value: $safeWithdrawalRate, in: 0.025...0.06, step: 0.0025)
                Text(String(format: "%.2f%%", safeWithdrawalRate * 100)).font(.caption.monospacedDigit())
            }
            .frame(maxWidth: 240)

            Spacer()
        }
    }

    private var tiers: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FI TIERS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            tierRow("Lean FI (15×)", target: summary.leanFI, tint: .blue)
            tierRow("Full FI (25×)", target: summary.fiNumber, tint: .green)
            tierRow("Fat FI (33×)", target: summary.fatFI, tint: .purple)
            HStack {
                Text("Coverage at current net worth:")
                    .font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f months of expenses", summary.coverageMonths))
                    .font(.caption.monospacedDigit().weight(.medium))
            }
            .padding(.top, 6)
        }
    }

    private func tierRow(_ label: String, target: Decimal, tint: Color) -> some View {
        let progress = NSDecimalNumber(decimal: summary.currentNetWorth).doubleValue / max(NSDecimalNumber(decimal: target).doubleValue, 1)
        return HStack(spacing: 10) {
            Image(systemName: progress >= 1 ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(progress >= 1 ? tint : .secondary)
            Text(label).font(.callout)
            Spacer()
            SecureAmount(amount: target, tint: tint, font: .callout.monospacedDigit())
            Text(String(format: "%.0f%%", min(progress, 1) * 100))
                .font(.caption.monospacedDigit())
                .foregroundStyle(progress >= 1 ? tint : .secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(tint.opacity(progress >= 1 ? 0.10 : 0.04)))
    }

    @ViewBuilder
    private func stat(_ label: String, _ amount: Decimal, tint: Color = .primary, showAsPercent: Bool = false, showAsYears: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if showAsPercent {
                Text(String(format: "%.1f%%", NSDecimalNumber(decimal: amount).doubleValue))
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(tint)
            } else if showAsYears {
                Text(String(format: "%.0f yr", NSDecimalNumber(decimal: amount).doubleValue))
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(tint)
            } else {
                SecureAmount(amount: amount, tint: tint, font: .title3.monospacedDigit().weight(.medium))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    @ViewBuilder
    private func statText(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }
}
