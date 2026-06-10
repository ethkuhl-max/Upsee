import SwiftUI
import SwiftData

struct TaxTrackerData {
    let payments: [TaxPayment]
    let personal: PersonalEntity?
    let jobs: [JobEntity]
    let apps: [AppEntity]

    var currentTaxYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var paymentsThisYear: [TaxPayment] {
        payments.filter { $0.taxYear == currentTaxYear }
    }

    var federalPaidThisYear: Decimal {
        paymentsThisYear.filter { $0.kind == .federal }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var statePaidThisYear: Decimal {
        paymentsThisYear.filter { $0.kind == .state }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var totalPaidThisYear: Decimal {
        paymentsThisYear.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Annualized income from active jobs + app revenue + personal income.
    var annualizedIncome: Decimal {
        let jobIncome = jobs.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.monthlyCompensation } * 12
        let appIncome = apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue } * 12
        let personalIncome = (personal?.monthlyIncome ?? 0) * 12
        return jobIncome + appIncome + personalIncome
    }

    var taxBreakdown: TaxBreakdown {
        let p = personal
        let seIncome = annualizedIncome * Decimal(p?.selfEmploymentPortion ?? 0)
        return IncomeTaxEngine.calculate(
            grossIncome: annualizedIncome,
            selfEmploymentIncome: seIncome,
            filingStatus: p?.filingStatus ?? .single,
            stateRate: p?.stateTaxRate ?? 0
        )
    }

    var stateAnnualOwed: Decimal {
        taxBreakdown.stateTax
    }

    var paidByQuarter: [Int: Decimal] {
        var result: [Int: Decimal] = [:]
        for p in paymentsThisYear {
            result[p.quarterNumber, default: 0] += p.amount
        }
        return result
    }
}

struct TaxPaymentTracker: View {
    let data: TaxTrackerData
    let onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var quarterlyTarget: Decimal {
        data.taxBreakdown.quarterlyPayment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryRow
            quartersBreakdown
            if !data.paymentsThisYear.isEmpty {
                recentPayments
            }
            if data.payments.isEmpty {
                EmptyHint(text: "Log your first quarterly payment to start tracking paid vs owed.")
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 18) {
            stat("Income (annualized)", currency(data.annualizedIncome))
            stat("Federal owed (est)", currency(data.taxBreakdown.federalTax), tint: .blue)
            stat("State owed (est)", currency(data.taxBreakdown.stateTax), tint: .green)
            stat("Paid YTD", currency(data.totalPaidThisYear))
            let target = data.taxBreakdown.totalTax
            let paid = data.totalPaidThisYear
            let remaining = target - paid
            stat("Remaining", currency(max(0, remaining)), tint: remaining > 0 ? .orange : .green)
            Spacer()
        }
    }

    private var quartersBreakdown: some View {
        HStack(spacing: 10) {
            ForEach(1...4, id: \.self) { quarter in
                let paid = data.paidByQuarter[quarter] ?? 0
                let target = quarterlyTarget
                let met = paid >= target && target > 0
                let due = TaxEstimator.dueDate(forYear: data.currentTaxYear, quarter: quarter)
                QuarterCard(
                    quarter: quarter,
                    paid: paid,
                    target: target,
                    met: met,
                    dueDate: due
                )
            }
        }
    }

    private var recentPayments: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Logged payments").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(data.paymentsThisYear) { payment in
                HStack {
                    Pill(text: "Q\(payment.quarterNumber)", tint: .blue)
                    Pill(text: payment.kind.displayName, tint: payment.kind.tint)
                    Text(payment.paidAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currency(payment.amount))
                        .font(.callout.monospacedDigit())
                    Button(role: .destructive) {
                        modelContext.delete(payment)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.05)))
            }
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }
}

private struct QuarterCard: View {
    let quarter: Int
    let paid: Decimal
    let target: Decimal
    let met: Bool
    let dueDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Q\(quarter)").font(.headline)
                Spacer()
                Image(systemName: met ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(met ? .green : .secondary)
            }
            Text(currency(paid)).font(.callout.monospacedDigit().weight(.medium))
            Text("Target: \(currency(target))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if let dueDate {
                Text("Due " + dueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(met ? Color.green.opacity(0.1) : Color.secondary.opacity(0.06))
        )
    }
}

struct AddTaxPaymentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var paidAt = Date()
    @State private var amount = ""
    @State private var quarter = 1
    @State private var taxYear = Calendar.current.component(.year, from: Date())
    @State private var kind: TaxPaymentKind = .federal
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Log Tax Payment").font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paid on").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        DatePicker("", selection: $paidAt, displayedComponents: [.date]).labelsHidden()
                    }
                    field("Amount", text: $amount, placeholder: "0")
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quarter").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Picker("Quarter", selection: $quarter) {
                                ForEach(1...4, id: \.self) { Text("Q\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented).labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tax year").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Stepper(value: $taxYear, in: 2020...2030) {
                                Text("\(taxYear)").monospacedDigit()
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kind").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Picker("Kind", selection: $kind) {
                                ForEach(TaxPaymentKind.allCases, id: \.self) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                            .pickerStyle(.menu).labelsHidden()
                        }
                    }
                    field("Note", text: $note, placeholder: "Optional")
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let payment = TaxPayment(
                        paidAt: paidAt,
                        amount: parseDecimal(amount),
                        quarterNumber: quarter,
                        taxYear: taxYear,
                        kind: kind,
                        note: note
                    )
                    modelContext.insert(payment)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parseDecimal(amount) <= 0)
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
