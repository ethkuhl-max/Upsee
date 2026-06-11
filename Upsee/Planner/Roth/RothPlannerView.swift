import SwiftUI
import SwiftData

struct RothPlannerView: View {
    @Query private var personal: [PersonalEntity]
    @State private var baseIncome: String = ""
    @State private var conversionAmount: String = "20000"
    @State private var filingStatus: FilingStatus = .single

    private var plan: RothConversionPlan {
        RothConversionEngine.plan(
            baseTaxableIncome: Decimal(string: baseIncome) ?? 0,
            conversionAmount: Decimal(string: conversionAmount) ?? 0,
            filingStatus: filingStatus
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            inputBlock
            sweetSpotCard
            bracketTable
            disclaimer
        }
        .onAppear {
            if baseIncome.isEmpty, let p = personal.first {
                let annual = NSDecimalNumber(decimal: p.monthlyIncome).doubleValue * 12
                baseIncome = String(Int(annual))
                filingStatus = p.filingStatus
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Roth conversion planner").font(.title3.weight(.semibold))
            Text("Between jobs or in a low-income year, converting pre-tax retirement balances to Roth at a known low rate locks in tax-free growth. This calculator shows exactly which brackets your conversion fills.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var inputBlock: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BASE TAXABLE INCOME").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("This year, before conversion", text: $baseIncome)
                    .textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 200)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("CONVERSION AMOUNT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Amount to convert", text: $conversionAmount)
                    .textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 200)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("FILING").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Picker("", selection: $filingStatus) {
                    ForEach(FilingStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu).labelsHidden().frame(maxWidth: 180)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private var sweetSpotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target").foregroundStyle(Color.green)
                Text("Sweet spot").font(.callout.weight(.semibold))
                Spacer()
            }
            HStack(spacing: 18) {
                statAmount("Fill current bracket", plan.recommendedFill, tint: .green)
                stat("Marginal rate", String(format: "%.0f%%", plan.recommendedRate * 100), tint: .green)
                statAmount("Tax on conversion", plan.totalTax, tint: .orange)
                stat("Effective rate", String(format: "%.1f%%", plan.effectiveRate * 100), tint: plan.effectiveRate < 0.18 ? .green : .orange)
                stat("Top bracket reached", String(format: "%.0f%%", plan.marginalRateReached * 100))
                Spacer()
            }
            Text("Convert exactly up to the top of your current marginal bracket. Anything beyond spills into the next bracket at a higher rate.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.green.opacity(0.18)))
    }

    private var bracketTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BRACKET FILL").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(plan.slots.filter { $0.suggestedFill > 0 }) { slot in
                HStack(spacing: 10) {
                    Text(String(format: "%.0f%%", slot.rate * 100))
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .frame(width: 50, alignment: .leading)
                        .foregroundStyle(tintForRate(slot.rate))
                    SecureAmount(amount: slot.suggestedFill, font: .callout.monospacedDigit())
                    Text("→ tax").font(.caption).foregroundStyle(.secondary)
                    SecureAmount(amount: slot.taxOnFill, tint: .orange, font: .callout.monospacedDigit())
                    Spacer()
                    Text("up to \(currency(slot.bracketTop))").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(tintForRate(slot.rate).opacity(0.08)))
            }
            if plan.slots.allSatisfy({ $0.suggestedFill == 0 }) {
                EmptyHint(text: "Enter a conversion amount above to see how it fills your brackets.")
            }
        }
    }

    private var disclaimer: some View {
        Text("Uses 2025 federal brackets after standard deduction. Doesn't account for state tax, IRMAA cliffs, ACA subsidies, NIIT, or pro-rata rule. For planning, not advice.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
    }

    private func statAmount(_ label: String, _ amount: Decimal, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            SecureAmount(amount: amount, tint: tint, font: .title3.monospacedDigit().weight(.medium))
        }
    }

    private func tintForRate(_ rate: Double) -> Color {
        switch rate {
        case 0..<0.13: return .green
        case 0.13..<0.23: return .blue
        case 0.23..<0.33: return .orange
        default: return .red
        }
    }
}
