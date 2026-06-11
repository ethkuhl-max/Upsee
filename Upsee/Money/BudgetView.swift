import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query private var transactions: [Transaction]

    @State private var addingFor: TxCategory?

    private var summary: BudgetSummary {
        BudgetEngine.summarize(budgets: budgets, transactions: transactions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !summary.overCategories.isEmpty { overSection }
            budgetedSection
            if !summary.underNoBudget.isEmpty { suggestionsSection }
        }
        .sheet(item: $addingFor) { cat in
            SetBudgetSheet(category: cat).frame(minWidth: 460, minHeight: 280)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            stat("Target", summary.totalTarget)
            stat("Spent", summary.totalActual, tint: summary.totalActual > summary.totalTarget ? .red : .primary)
            stat("Remaining", max(0, summary.totalTarget - summary.totalActual),
                 tint: summary.totalActual < summary.totalTarget ? .green : .red)
            stat("Categories", Decimal(budgets.count))
            Spacer()
        }
    }

    private var overSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OVER BUDGET").font(.caption.weight(.bold)).foregroundStyle(.red)
            ForEach(summary.overCategories) { line in
                BudgetLineRow(line: line, onAdjust: { addingFor = line.category })
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.06)))
    }

    private var budgetedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS MONTH").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if summary.lines.filter({ $0.status != .underNoBudget && $0.status != .over }).isEmpty {
                EmptyHint(text: "Set budgets per category to track variance.")
            } else {
                ForEach(summary.lines.filter { $0.status != .underNoBudget && $0.status != .over }) { line in
                    BudgetLineRow(line: line, onAdjust: { addingFor = line.category })
                }
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("UNBUDGETED SPENDING").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("Tap to set a budget").font(.caption2).foregroundStyle(.tertiary)
            }
            ForEach(summary.underNoBudget) { line in
                Button {
                    addingFor = line.category
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: line.category.systemImage).foregroundStyle(line.category.tint)
                        Text(line.category.displayName).font(.callout)
                        Spacer()
                        SecureAmount(amount: line.actual, font: .callout.monospacedDigit())
                        Image(systemName: "plus.circle").foregroundStyle(.blue)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stat(_ label: String, _ amount: Decimal, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            SecureAmount(amount: amount, tint: tint, font: .title3.monospacedDigit().weight(.medium))
        }
        .padding(12)
        .glassPanel(cornerRadius: 14)
    }
}

private struct BudgetLineRow: View {
    let line: BudgetLine
    let onAdjust: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: line.category.systemImage).foregroundStyle(line.category.tint)
                Text(line.category.displayName).font(.callout.weight(.medium))
                Spacer()
                SecureAmount(amount: line.actual, tint: statusTint, font: .callout.monospacedDigit())
                Text("/").foregroundStyle(.tertiary)
                SecureAmount(amount: line.target, tint: .secondary, font: .callout.monospacedDigit())
                Button(action: onAdjust) {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                    Rectangle()
                        .fill(statusTint.opacity(0.7))
                        .frame(width: geo.size.width * min(line.utilization, 1.5))
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
            HStack {
                Text("\(Int(line.utilization * 100))% used").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                if line.remaining >= 0 {
                    Text("Remaining: ").font(.caption2).foregroundStyle(.secondary) + Text(currency(line.remaining)).font(.caption2.monospacedDigit())
                } else {
                    Text("Over by ").font(.caption2).foregroundStyle(.red) + Text(currency(-line.remaining)).font(.caption2.monospacedDigit()).foregroundColor(.red)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }

    private var statusTint: Color {
        switch line.status {
        case .onTrack: return .green
        case .approaching: return .orange
        case .over: return .red
        case .underNoBudget: return .secondary
        }
    }
}

struct SetBudgetSheet: View {
    let category: TxCategory

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [Budget]

    @State private var amount: String = ""

    private var existing: Budget? {
        budgets.first { $0.category == category }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage).foregroundStyle(category.tint).font(.title2)
                Text("Budget — \(category.displayName)").font(.title3.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("MONTHLY TARGET").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("0", text: $amount).textFieldStyle(.roundedBorder).monospacedDigit()
            }
            Spacer()
            HStack {
                if existing != nil {
                    Button("Remove", role: .destructive) {
                        if let existing { modelContext.delete(existing); try? modelContext.save() }
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    let amt = parseDecimal(amount)
                    if let existing {
                        existing.monthlyTarget = amt
                        existing.updatedAt = Date()
                    } else {
                        let b = Budget(category: category, monthlyTarget: amt)
                        modelContext.insert(b)
                    }
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parseDecimal(amount) <= 0)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .onAppear {
            if let existing { amount = NSDecimalNumber(decimal: existing.monthlyTarget).stringValue }
        }
    }

    private func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}
