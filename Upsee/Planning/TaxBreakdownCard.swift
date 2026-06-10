import SwiftUI

struct TaxBreakdownCard: View {
    let breakdown: TaxBreakdown
    let filingStatus: FilingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                metric("Total tax", currency(breakdown.totalTax), tint: .primary)
                metric("Effective rate", percent(breakdown.effectiveRate))
                metric("Marginal rate", percent(breakdown.marginalRate))
                metric("After-tax", currency(breakdown.afterTaxIncome), tint: .green)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                line("Gross income", currency(breakdown.grossIncome))
                line("Less: standard deduction (\(filingStatus.displayName))",
                     "−" + currency(breakdown.standardDeduction))
                line("Federal taxable", currency(breakdown.taxableIncome))
                Divider().padding(.vertical, 2)
                line("Federal income tax", currency(breakdown.federalTax))
                if breakdown.selfEmploymentTax > 0 {
                    line("Self-employment tax", currency(breakdown.selfEmploymentTax))
                }
                if breakdown.stateTax > 0 {
                    line("State tax", currency(breakdown.stateTax))
                }
                line("Quarterly estimate", currency(breakdown.quarterlyPayment), emphasized: true)
            }

            if let due = breakdown.nextDueDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                    Text("Next quarterly estimated payment due " + Self.dateFormatter.string(from: due))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Estimate only. 2025 federal brackets + SECA + flat state. Not tax advice.")
                .font(.caption2.italic())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func metric(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ label: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasized ? .callout.weight(.semibold) : .callout)
                .foregroundStyle(emphasized ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit())
                .fontWeight(emphasized ? .semibold : .regular)
        }
    }

    private func percent(_ d: Double) -> String { String(format: "%.1f%%", d * 100) }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
}
