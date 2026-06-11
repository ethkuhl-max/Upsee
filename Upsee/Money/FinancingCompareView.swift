import SwiftUI

struct FinancingCompareView: View {
    @State private var purchasePrice: String = "30000"
    @State private var availableCash: String = "50000"
    @State private var assumedReturn: Double = 0.07

    @State private var cashOption = FinancingOption(name: "Cash", kind: .cash, downPayment: 0, apr: 0, termMonths: 0, residual: 0, fixedMonthlyPayment: 0)
    @State private var loanOption = FinancingOption(name: "Auto loan", kind: .loan, downPayment: 5000, apr: 0.0625, termMonths: 60, residual: 0, fixedMonthlyPayment: 0)
    @State private var leaseOption = FinancingOption(name: "Lease", kind: .lease, downPayment: 3000, apr: 0, termMonths: 36, residual: 18000, fixedMonthlyPayment: 450)

    private var price: Decimal { Decimal(string: purchasePrice) ?? 0 }
    private var cash: Decimal { Decimal(string: availableCash) ?? 0 }

    private var comparisons: [FinancingComparison] {
        FinancingCompareEngine.compare(
            purchasePrice: price,
            options: [cashOption, loanOption, leaseOption],
            assumedReturn: assumedReturn,
            availableCash: cash
        )
    }

    private var bestByTrueCost: FinancingComparison? {
        comparisons.min { $0.trueCost < $1.trueCost }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            inputsBlock
            optionsBlock
            resultsBlock
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cash vs loan vs lease").font(.callout.weight(.semibold))
            Text("Plug in a purchase price and compare what each financing approach actually costs you — including the opportunity cost of cash that's no longer earning a return.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var inputsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                input("Purchase price", text: $purchasePrice)
                input("Available cash", text: $availableCash)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ASSUMED RETURN").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $assumedReturn, in: 0.0...0.12, step: 0.005)
                        Text(String(format: "%.1f%%", assumedReturn * 100))
                            .font(.caption.monospacedDigit())
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private var optionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options").font(.callout.weight(.semibold))
            optionRow($cashOption)
            optionRow($loanOption)
            optionRow($leaseOption)
        }
    }

    @ViewBuilder
    private func optionRow(_ option: Binding<FinancingOption>) -> some View {
        let isCash = option.wrappedValue.kind == .cash
        let isLease = option.wrappedValue.kind == .lease
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Pill(text: option.wrappedValue.kind.displayName, tint: tint(option.wrappedValue.kind))
                TextField("Name", text: option.name).textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                Spacer()
            }
            HStack(spacing: 10) {
                inlineDecimal("Down", binding: option.downPayment)
                if !isCash {
                    inlineDecimal("APR%", binding: bindingForAPRPct(option))
                    inlineInt("Term (mo)", binding: option.termMonths)
                }
                if isLease {
                    inlineDecimal("Residual", binding: option.residual)
                    inlineDecimal("Monthly", binding: option.fixedMonthlyPayment)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint(option.wrappedValue.kind).opacity(0.05)))
    }

    private var resultsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Result").font(.callout.weight(.semibold))
            ForEach(comparisons) { comp in
                resultCard(comp)
            }
            if let best = bestByTrueCost {
                Text("Lowest true cost (incl. opportunity cost): \(best.option.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
                    .padding(.top, 4)
            }
        }
    }

    private func resultCard(_ comp: FinancingComparison) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comp.option.name).font(.callout.weight(.medium))
                Pill(text: comp.option.kind.displayName, tint: tint(comp.option.kind))
                Spacer()
                Text("True cost: \(currency(comp.trueCost))")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(comp.id == bestByTrueCost?.id ? Color.green : .primary)
            }
            HStack(spacing: 18) {
                stat("Monthly", currency(comp.monthlyPayment))
                stat("Total cash out", currency(comp.totalCashOut))
                stat("Finance cost", currency(comp.financeCost), tint: .orange)
                stat("Opportunity cost", currency(comp.opportunityCost), tint: .secondary)
                stat("Ending equity", currency(comp.endingEquity), tint: .green)
                Spacer()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
    }

    private func input(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextField("", text: text).textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 140)
        }
    }

    private func inlineDecimal(_ label: String, binding: Binding<Decimal>) -> some View {
        let stringBinding = Binding<String>(
            get: { NSDecimalNumber(decimal: binding.wrappedValue).stringValue },
            set: { binding.wrappedValue = Decimal(string: $0) ?? 0 }
        )
        return VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("", text: stringBinding)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(width: 100)
        }
    }

    private func inlineInt(_ label: String, binding: Binding<Int>) -> some View {
        let stringBinding = Binding<String>(
            get: { String(binding.wrappedValue) },
            set: { binding.wrappedValue = Int($0) ?? 0 }
        )
        return VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("", text: stringBinding)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(width: 80)
        }
    }

    private func bindingForAPRPct(_ opt: Binding<FinancingOption>) -> Binding<Decimal> {
        Binding<Decimal>(
            get: { Decimal(opt.wrappedValue.apr * 100) },
            set: { opt.wrappedValue.apr = NSDecimalNumber(decimal: $0).doubleValue / 100 }
        )
    }

    private func tint(_ kind: FinancingKind) -> Color {
        switch kind {
        case .cash: return .green
        case .loan: return .blue
        case .lease: return .orange
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(tint)
        }
    }
}
