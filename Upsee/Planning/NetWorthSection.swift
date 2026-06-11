import SwiftUI
import SwiftData

struct NetWorthSection: View {
    let items: [BalanceSheetItem]
    @Environment(\.modelContext) private var modelContext
    @State private var addingItem = false

    private var summary: NetWorthSummary { NetWorthEngine.summarize(items) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                metric("Net worth", currency(summary.netWorth), tint: summary.netWorth >= 0 ? .green : .red)
                metric("Assets", currency(summary.totalAssets))
                metric("Liabilities", currency(summary.totalLiabilities), tint: .orange)
                metric("Leverage", String(format: "%.0f%%", summary.leverageRatio * 100))
            }

            if items.isEmpty {
                EmptyHint(text: "Add your assets and debts to track net worth — it seeds the wealth projection above.")
            } else {
                itemGroup("Assets", items.filter { $0.isAsset })
                itemGroup("Liabilities", items.filter { !$0.isAsset })
            }

            Button { addingItem = true } label: {
                Label("Add line item", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $addingItem) {
            AddBalanceSheetItemSheet()
                .frame(minWidth: 460, minHeight: 340)
        }
    }

    private func itemGroup(_ title: String, _ groupItems: [BalanceSheetItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(groupItems.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 10) {
                    Image(systemName: item.category.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).font(.callout)
                        Text(item.category.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(currency(item.amount))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(item.isAsset ? Color.primary : Color.orange)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(item)
                        try? modelContext.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
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
        .padding(12)
        .glassPanel(cornerRadius: 14)
    }
}

struct AddBalanceSheetItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: BalanceSheetCategory = .cash
    @State private var amount = ""
    @State private var apr = ""
    @State private var minimumPayment = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add balance sheet item").font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 14) {
                field("Name") {
                    TextField("e.g. Brokerage account", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                field("Category") {
                    Picker("Category", selection: $category) {
                        Section("Assets") {
                            ForEach(BalanceSheetCategory.assetCases, id: \.self) { c in
                                Label(c.displayName, systemImage: c.systemImage).tag(c)
                            }
                        }
                        Section("Liabilities") {
                            ForEach(BalanceSheetCategory.liabilityCases, id: \.self) { c in
                                Label(c.displayName, systemImage: c.systemImage).tag(c)
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                field(category.isAsset ? "Amount" : "Balance owed") {
                    TextField("0", text: $amount)
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                }
                if !category.isAsset {
                    field("APR (%)") {
                        TextField("0", text: $apr)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                    }
                    field("Minimum monthly payment") {
                        TextField("0", text: $minimumPayment)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                    }
                    Text("APR and minimum payment power the debt payoff planner.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func save() {
        let item = BalanceSheetItem(
            name: name,
            amount: parseDecimal(amount),
            category: category,
            apr: category.isAsset ? 0 : (Double(apr) ?? 0) / 100.0,
            minimumPayment: category.isAsset ? 0 : parseDecimal(minimumPayment)
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }

    private func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}
