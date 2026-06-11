import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LockManager.self) private var lockManager

    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]

    @State private var adding = false

    private var summary: BillCalendarSummary {
        BillScheduleEngine.summarize(bills)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !summary.overdue.isEmpty { overdueSection }
                if !summary.dueThisWeek.isEmpty { dueThisWeekSection }
                upcomingSection
                allBillsSection
            }
            .padding(24)
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add bill", systemImage: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $adding) {
            AddBillSheet().frame(minWidth: 520, minHeight: 480)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            stat("Active bills", "\(bills.filter { $0.isActive }.count)")
            statAmount("Monthly committed", summary.monthlyCommitted, tint: .orange)
            statAmount("This week", summary.dueThisWeek.reduce(Decimal(0)) { $0 + $1.amount }, tint: .blue)
            stat("Overdue", "\(summary.overdue.count)", tint: summary.overdue.isEmpty ? .secondary : .red)
            Spacer()
        }
    }

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
                Text("OVERDUE").font(.caption.weight(.bold)).foregroundStyle(.red)
            }
            ForEach(summary.overdue) { occ in
                BillOccurrenceRow(occurrence: occ, onMarkPaid: { markPaid(occ.bill) })
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.25)))
    }

    private var dueThisWeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DUE THIS WEEK").font(.caption.weight(.bold)).foregroundStyle(.orange)
            ForEach(summary.dueThisWeek) { occ in
                BillOccurrenceRow(occurrence: occ, onMarkPaid: { markPaid(occ.bill) })
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.07)))
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT 30 DAYS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if summary.upcomingMonth.isEmpty {
                EmptyHint(text: "Nothing's due in the next 30 days.")
            } else {
                ForEach(summary.upcomingMonth) { occ in
                    BillOccurrenceRow(occurrence: occ, onMarkPaid: { markPaid(occ.bill) })
                }
            }
        }
    }

    private var allBillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALL BILLS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if bills.isEmpty {
                EmptyHint(text: "No bills yet. Add rent, utilities, credit card minimum, subscriptions, taxes — anything that recurs.")
            } else {
                ForEach(bills) { bill in
                    BillRow(bill: bill, onDelete: {
                        modelContext.delete(bill)
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

    private func markPaid(_ bill: Bill) {
        bill.lastPaidAt = Date()
        bill.advance()
        try? modelContext.save()
    }
}

private struct BillOccurrenceRow: View {
    let occurrence: BillOccurrence
    let onMarkPaid: () -> Void

    @Environment(LockManager.self) private var lockManager

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(occurrence.bill.category.tint.opacity(0.15)).frame(width: 30, height: 30)
                Image(systemName: occurrence.bill.category.systemImage)
                    .foregroundStyle(occurrence.bill.category.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(occurrence.bill.name).font(.callout.weight(.medium))
                    if occurrence.bill.autopay {
                        Pill(text: "Autopay", tint: .green)
                    }
                }
                HStack(spacing: 6) {
                    Text(occurrence.dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.monospaced())
                    Text("·").foregroundStyle(.tertiary)
                    Text(daysLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(daysTint)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            SecureAmount(amount: occurrence.amount, font: .callout.monospacedDigit().weight(.medium))
            Button("Paid") { onMarkPaid() }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(occurrence.bill.autopay)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }

    private var daysLabel: String {
        let d = occurrence.daysFromNow
        if d < 0 { return "\(-d)d overdue" }
        if d == 0 { return "Due today" }
        if d == 1 { return "Tomorrow" }
        return "in \(d)d"
    }

    private var daysTint: Color {
        let d = occurrence.daysFromNow
        if d < 0 { return .red }
        if d <= 3 { return .orange }
        return .secondary
    }
}

private struct BillRow: View {
    let bill: Bill
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: bill.category.systemImage)
                .foregroundStyle(bill.category.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name).font(.callout.weight(.medium))
                Text("\(bill.cadence.displayName) · next \(bill.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                SecureAmount(amount: bill.amount)
                SecureAmount(amount: bill.monthlyEquivalent(), tint: .secondary, font: .caption2.monospacedDigit())
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

struct AddBillSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var payee = ""
    @State private var amount = ""
    @State private var nextDueDate = Date()
    @State private var cadence: BillCadence = .monthly
    @State private var category: TxCategory = .utilities
    @State private var autopay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add bill").font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                field("Name", text: $name, placeholder: "PG&E / Rent / Visa minimum")
                field("Payee", text: $payee, placeholder: "PG&E / Wells Fargo / etc")
            }

            HStack(spacing: 10) {
                field("Amount", text: $amount, placeholder: "0")
                VStack(alignment: .leading, spacing: 4) {
                    Text("CADENCE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Cadence", selection: $cadence) {
                        ForEach(BillCadence.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("CATEGORY").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Category", selection: $category) {
                        ForEach(TxCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT DUE DATE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                DatePicker("", selection: $nextDueDate, displayedComponents: [.date]).labelsHidden()
            }

            Toggle("On autopay", isOn: $autopay).toggleStyle(.switch)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let bill = Bill(
                        name: name,
                        payee: payee,
                        amount: parseDecimal(amount),
                        nextDueDate: nextDueDate,
                        cadence: cadence,
                        category: category,
                        autopay: autopay
                    )
                    modelContext.insert(bill)
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
