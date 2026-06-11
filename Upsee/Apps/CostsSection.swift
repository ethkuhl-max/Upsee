import SwiftUI
import SwiftData

struct CostsSection: View {
    let app: AppEntity

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppCost.createdAt, order: .reverse) private var allCosts: [AppCost]

    @State private var addingCost = false

    private var appCosts: [AppCost] {
        allCosts.filter { $0.entityKind == "app" && $0.entityLabel == app.name }
    }

    private var totalMonthly: Decimal {
        appCosts.reduce(Decimal(0)) { $0 + $1.monthlyEquivalent() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                statRow
                Spacer()
                Button {
                    addingCost = true
                } label: {
                    Label("Add cost", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if appCosts.isEmpty {
                EmptyHint(text: "Track every dollar going out — services, ads, contractors, Apple's cut. Net profit only matters if costs are honest.")
            } else {
                ForEach(appCosts) { cost in
                    CostRow(cost: cost, onDelete: {
                        modelContext.delete(cost)
                        try? modelContext.save()
                    })
                }
            }
        }
        .sheet(isPresented: $addingCost) {
            AddCostSheet(entityKind: "app", entityLabel: app.name).frame(minWidth: 520, minHeight: 440)
        }
    }

    private var statRow: some View {
        HStack(spacing: 16) {
            stat("Monthly burn", currency(totalMonthly), tint: totalMonthly > 0 ? .orange : .secondary)
            stat("Annualized", currency(totalMonthly * 12), tint: .secondary)
            stat("Items", "\(appCosts.count)")
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }
}

private struct CostRow: View {
    let cost: AppCost
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: cost.category.systemImage)
                .foregroundStyle(cost.category.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(cost.name).font(.callout.weight(.medium))
                Text("\(cost.category.displayName) · \(cost.cadence.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(currency(cost.amount)).font(.callout.monospacedDigit())
                Text("\(currency(cost.monthlyEquivalent()))/mo")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.05)))
    }
}

struct AddCostSheet: View {
    let entityKind: String
    let entityLabel: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var cadence: CostCadence = .monthly
    @State private var category: CostCategory = .service
    @State private var startedAt: Date = Date()
    @State private var note: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add cost — \(entityLabel)").font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("NAME").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("RevenueCat / Twitter ads / Designer for Q3", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AMOUNT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("0", text: $amount).textFieldStyle(.roundedBorder).monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("CADENCE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Cadence", selection: $cadence) {
                        ForEach(CostCadence.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("CATEGORY").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Category", selection: $category) {
                        ForEach(CostCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("STARTED").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                DatePicker("", selection: $startedAt, displayedComponents: [.date]).labelsHidden()
            }

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let cost = AppCost(
                        name: name,
                        entityKind: entityKind,
                        entityLabel: entityLabel,
                        amount: parseDecimal(amount),
                        cadence: cadence,
                        category: category,
                        startedAt: startedAt
                    )
                    modelContext.insert(cost)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || parseDecimal(amount) <= 0)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
    }

    private func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}
