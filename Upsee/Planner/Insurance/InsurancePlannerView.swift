import SwiftUI
import SwiftData

struct InsurancePlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InsurancePolicy.updatedAt, order: .reverse) private var policies: [InsurancePolicy]
    @Query private var personal: [PersonalEntity]
    @Query private var jobs: [JobEntity]
    @Query private var apps: [AppEntity]
    @Query private var balanceSheet: [BalanceSheetItem]
    @Query private var loans: [Loan]

    @State private var adding = false
    @State private var debt: String = ""
    @State private var mortgage: String = ""
    @State private var yearsReplacement: Int = 10

    private var annualIncome: Decimal {
        let jobIncome = jobs.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.monthlyCompensation } * 12
        let appIncome = apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue } * 12
        let personalIncome = (personal.first?.monthlyIncome ?? 0) * 12
        return jobIncome + appIncome + personalIncome
    }

    private var netWorth: Decimal {
        balanceSheet.reduce(Decimal(0)) { partial, item in
            partial + (item.category.isAsset ? item.amount : -item.amount)
        }
    }

    private var monthlyExpenses: Decimal {
        personal.first?.monthlyExpenses ?? 0
    }

    private var totalDebt: Decimal {
        let manual = Decimal(string: debt) ?? 0
        return manual > 0 ? manual : loans.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    private var mortgageBalance: Decimal {
        let manual = Decimal(string: mortgage) ?? 0
        return manual > 0 ? manual : loans.filter { $0.kind == .mortgage }.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    private var summary: InsuranceGapSummary {
        InsuranceGapEngine.summarize(
            policies: policies,
            annualIncome: annualIncome,
            netWorth: netWorth,
            monthlyExpenses: monthlyExpenses,
            debt: totalDebt,
            mortgageBalance: mortgageBalance,
            yearsOfIncomeReplacement: yearsReplacement
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            statsRow
            inputBlock
            if !summary.underInsured.isEmpty { gapBanner }
            gapsList
            policiesSection
        }
        .sheet(isPresented: $adding) {
            AddPolicySheet().frame(minWidth: 520, minHeight: 480)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Insurance gap analysis").font(.title3.weight(.semibold))
            Text("Standard CFP heuristics: 10× income (or DIME) for life, 60% income replacement for disability, $1M umbrella per $1M of net worth.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            statAmount("Annual income", annualIncome)
            statAmount("Net worth", netWorth)
            statAmount("Premiums/mo", summary.totalMonthlyPremium, tint: .orange)
            stat("Underinsured", "\(summary.underInsured.count)", tint: summary.underInsured.isEmpty ? .green : .red)
            Spacer()
        }
    }

    private var inputBlock: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EXTRA DEBT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("auto from Loans", text: $debt).textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 120)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("MORTGAGE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("auto from Loans", text: $mortgage).textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 120)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("INCOME YRS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Stepper(value: $yearsReplacement, in: 5...20) { Text("\(yearsReplacement)yrs").monospacedDigit() }
            }
            Spacer()
            Button { adding = true } label: {
                Label("Add policy", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private var gapBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.slash").foregroundStyle(.red)
            Text("\(summary.underInsured.count) coverage gap\(summary.underInsured.count == 1 ? "" : "s") flagged")
                .font(.callout.weight(.semibold))
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.20)))
    }

    private var gapsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COVERAGE BY TYPE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(summary.lines) { line in
                GapRow(line: line)
            }
        }
    }

    private var policiesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR POLICIES").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if policies.isEmpty {
                EmptyHint(text: "Add your existing policies to see real gap analysis against your specific needs.")
            } else {
                ForEach(policies) { policy in
                    PolicyRow(policy: policy, onDelete: {
                        modelContext.delete(policy)
                        try? modelContext.save()
                    })
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func statAmount(_ label: String, _ amount: Decimal, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            SecureAmount(amount: amount, tint: tint, font: .title3.monospacedDigit().weight(.medium))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }
}

private struct GapRow: View {
    let line: InsuranceGapLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: line.kind.systemImage).foregroundStyle(line.kind.tint)
                Text(line.kind.displayName).font(.callout.weight(.medium))
                Spacer()
                Pill(text: line.status.displayName, tint: statusTint)
            }
            HStack(spacing: 14) {
                statBlock("Need", line.need)
                statBlock("Have", line.current, tint: line.current >= line.need ? .green : .primary)
                if line.gap > 0 {
                    statBlock("Gap", line.gap, tint: .red)
                }
                Spacer()
            }
            Text(line.rationale).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(line.kind.tint.opacity(0.05)))
    }

    private var statusTint: Color {
        switch line.status {
        case .adequate: return .green
        case .under: return .red
        case .over: return .orange
        case .notApplicable: return .secondary
        }
    }

    private func statBlock(_ label: String, _ amount: Decimal, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            SecureAmount(amount: amount, tint: tint, font: .caption.monospacedDigit())
        }
    }
}

private struct PolicyRow: View {
    let policy: InsurancePolicy
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: policy.kind.systemImage).foregroundStyle(policy.kind.tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(policy.name).font(.callout.weight(.medium))
                Text("\(policy.kind.displayName)\(policy.insurer.isEmpty ? "" : " · \(policy.insurer)")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                SecureAmount(amount: policy.coverageAmount)
                SecureAmount(amount: policy.monthlyPremium, tint: .secondary, font: .caption2.monospacedDigit())
            }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }
}

struct AddPolicySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var insurer = ""
    @State private var kind: InsuranceKind = .termLife
    @State private var coverage = ""
    @State private var premium = ""
    @State private var beneficiary = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add policy").font(.title3.weight(.semibold))
            HStack(spacing: 10) {
                field("Name", text: $name, placeholder: "Term life 20yr")
                field("Insurer", text: $insurer, placeholder: "Northwestern Mutual")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("KIND").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Kind", selection: $kind) {
                    ForEach(InsuranceKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu).labelsHidden()
            }
            HStack(spacing: 10) {
                field("Coverage", text: $coverage, placeholder: "500000")
                field("Monthly premium", text: $premium, placeholder: "75")
            }
            field("Beneficiary", text: $beneficiary, placeholder: "Spouse / Trust")
            Spacer()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let p = InsurancePolicy(
                        name: name, insurer: insurer, kind: kind,
                        coverageAmount: parseDecimal(coverage),
                        monthlyPremium: parseDecimal(premium),
                        beneficiary: beneficiary
                    )
                    modelContext.insert(p)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder).monospacedDigit()
        }
    }

    private func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}
