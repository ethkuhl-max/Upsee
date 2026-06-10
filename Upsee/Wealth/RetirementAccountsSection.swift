import SwiftUI
import SwiftData

struct RetirementAccountsSection: View {
    let accounts: [RetirementAccount]
    let onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var totalBalance: Decimal {
        accounts.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    private var preTaxBalance: Decimal {
        accounts.filter { $0.kind.isPreTax }.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    private var afterTaxBalance: Decimal {
        accounts.filter { $0.kind.isAfterTax }.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    var body: some View {
        if accounts.isEmpty {
            EmptyHint(text: "Add an IRA, 401(k), HSA, or Solo 401(k) to track contribution headroom and tax mix.")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                summaryRow
                ForEach(accounts) { account in
                    AccountRow(account: account, onDelete: {
                        modelContext.delete(account)
                        try? modelContext.save()
                    })
                }
                if afterTaxBalance > 0 {
                    rothCommentary
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 18) {
            stat("Total", currency(totalBalance))
            stat("Pre-tax", currency(preTaxBalance), tint: .blue)
            stat("Roth", currency(afterTaxBalance), tint: .purple)
            let totalDouble = NSDecimalNumber(decimal: totalBalance).doubleValue
            let rothDouble = NSDecimalNumber(decimal: afterTaxBalance).doubleValue
            let rothPct = totalDouble > 0 ? rothDouble / totalDouble : 0
            stat("Roth %", String(format: "%.0f%%", rothPct * 100), tint: rothPct >= 0.3 ? .green : .orange)
            Spacer()
        }
    }

    private var rothCommentary: some View {
        let totalDouble = NSDecimalNumber(decimal: totalBalance).doubleValue
        let rothDouble = NSDecimalNumber(decimal: afterTaxBalance).doubleValue
        let pct = totalDouble > 0 ? rothDouble / totalDouble : 0
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: pct >= 0.3 ? "checkmark.seal" : "exclamationmark.triangle")
                .foregroundStyle(pct >= 0.3 ? .green : .orange)
            Text(pct >= 0.3
                 ? "Roth mix is healthy — diversified tax exposure in retirement."
                 : "Roth share is under 30%. In low-income years (gaps between jobs), Roth conversions move pre-tax balance into the after-tax bucket at a known cost.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }
}

private struct AccountRow: View {
    let account: RetirementAccount
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(account.name).font(.callout.weight(.medium))
                Pill(text: account.kind.displayName, tint: account.kind.tint)
                Pill(text: account.kind.taxTreatmentLabel, tint: .secondary)
                Spacer()
                Text(currency(account.currentBalance))
                    .font(.callout.monospacedDigit().weight(.semibold))
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 12) {
                Text("\(currency(account.contributionsYTD)) / \(currency(account.kind.annualLimit2026)) YTD")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: account.contributionProgress)
                    .tint(account.kind.tint)
                    .frame(maxWidth: 220)
                Text("Headroom: \(currency(account.headroom))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(account.headroom > 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.green))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }
}

struct AddRetirementAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: RetirementAccountKind = .rothIRA
    @State private var currentBalance = ""
    @State private var contributionsYTD = ""
    @State private var employerMatchYTD = ""
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Retirement Account").font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Name", text: $name, placeholder: "Fidelity Roth IRA")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kind").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Kind", selection: $kind) {
                            ForEach(RetirementAccountKind.allCases, id: \.self) { k in
                                Text(k.displayName).tag(k)
                            }
                        }
                        .pickerStyle(.menu).labelsHidden()
                    }
                    field("Current balance", text: $currentBalance, placeholder: "0")
                    field("Contributions YTD", text: $contributionsYTD, placeholder: "0")
                    field("Employer match YTD", text: $employerMatchYTD, placeholder: "0 (optional)")
                    Text("2026 contribution limit for \(kind.displayName): \(currency(kind.annualLimit2026))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let account = RetirementAccount(
                        name: name,
                        kind: kind,
                        currentBalance: parseDecimal(currentBalance),
                        contributionsYTD: parseDecimal(contributionsYTD),
                        employerMatchYTD: parseDecimal(employerMatchYTD)
                    )
                    account.note = note
                    modelContext.insert(account)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder).monospacedDigit()
        }
    }

    private func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}
