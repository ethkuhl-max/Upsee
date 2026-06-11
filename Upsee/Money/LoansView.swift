import SwiftUI
import SwiftData
import Charts

struct LoansView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Loan.updatedAt, order: .reverse) private var loans: [Loan]

    @State private var adding = false
    @State private var selected: Loan?
    @State private var tab: TopTab = .portfolio

    enum TopTab: String, CaseIterable {
        case portfolio, financing
        var displayName: String {
            switch self {
            case .portfolio: return "Loans"
            case .financing: return "Financing comparison"
            }
        }
    }

    private var totalBalance: Decimal {
        loans.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    private var totalMonthlyPayment: Decimal {
        loans.reduce(Decimal(0)) { $0 + $1.monthlyPayment + $1.extraPayment }
    }

    private var weightedAPR: Double {
        let total = NSDecimalNumber(decimal: totalBalance).doubleValue
        guard total > 0 else { return 0 }
        let weighted = loans.reduce(0.0) {
            $0 + NSDecimalNumber(decimal: $1.currentBalance).doubleValue * $1.apr
        }
        return weighted / total
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Tab", selection: $tab) {
                    ForEach(TopTab.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                switch tab {
                case .portfolio: portfolioTab
                case .financing: FinancingCompareView()
                }
            }
            .padding(24)
        }
        .navigationTitle("Loans")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add loan", systemImage: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $adding) {
            AddLoanSheet().frame(minWidth: 560, minHeight: 540)
        }
        .sheet(item: $selected) { loan in
            LoanDetailView(loan: loan).frame(minWidth: 720, minHeight: 600)
        }
    }

    @ViewBuilder
    private var portfolioTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            portfolioHeader
            if loans.isEmpty {
                EmptyHint(text: "Add a mortgage, student loan, auto loan, or credit card to see amortization, payoff dates, and extra-payment scenarios.")
            } else {
                ForEach(loans) { loan in
                    LoanCard(loan: loan, onOpen: { selected = loan })
                }
                payoffOrderSection
            }
        }
    }

    private var portfolioHeader: some View {
        HStack(spacing: 14) {
            stat("Total balance", currency(totalBalance), tint: .red)
            stat("Monthly", currency(totalMonthlyPayment), tint: .orange)
            stat("Weighted APR", String(format: "%.2f%%", weightedAPR * 100))
            stat("Loans", "\(loans.count)")
            Spacer()
        }
    }

    private var payoffOrderSection: some View {
        let avalanche = loans.sorted { $0.apr > $1.apr }
        let snowball = loans.sorted { $0.currentBalance < $1.currentBalance }
        return VStack(alignment: .leading, spacing: 8) {
            Text("PAYOFF ORDER").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                payoffColumn(title: "Avalanche (highest APR first)", loans: avalanche)
                payoffColumn(title: "Snowball (smallest balance first)", loans: snowball)
            }
        }
    }

    private func payoffColumn(title: String, loans: [Loan]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold))
            ForEach(loans) { loan in
                HStack(spacing: 6) {
                    Image(systemName: loan.kind.systemImage).font(.caption2).foregroundStyle(loan.kind.tint)
                    Text(loan.name).font(.caption)
                    Spacer()
                    Text(currency(loan.currentBalance)).font(.caption.monospacedDigit())
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.05)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .padding(12)
        .glassPanel(cornerRadius: 14)
    }
}

private struct LoanCard: View {
    let loan: Loan
    let onOpen: () -> Void

    private var schedule: LoanSchedule {
        LoanScheduleEngine.schedule(
            principal: loan.currentBalance,
            apr: loan.apr,
            termMonths: loan.termMonths,
            monthlyPayment: loan.monthlyPayment,
            extraPayment: loan.extraPayment,
            startDate: Date()
        )
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: loan.kind.systemImage).foregroundStyle(loan.kind.tint).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loan.name).font(.callout.weight(.semibold))
                        Text("\(loan.kind.displayName) · \(loan.lender)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currency(loan.currentBalance)).font(.callout.monospacedDigit().weight(.medium))
                        Text(String(format: "%.2f%% APR", loan.apr * 100)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 18) {
                    stat("Monthly", currency(loan.monthlyPayment + loan.extraPayment))
                    if let payoff = schedule.payoffDate {
                        stat("Payoff", payoff.formatted(.dateTime.month().year()))
                    }
                    stat("Lifetime interest", currency(schedule.totalInterest), tint: .orange)
                    if schedule.monthsSaved > 0 {
                        stat("Saved", "\(schedule.monthsSaved)mo / \(currency(schedule.interestSaved))", tint: .green)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(loan.kind.tint.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(loan.kind.tint.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(tint)
        }
    }
}

struct LoanDetailView: View {
    @Bindable var loan: Loan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var extraScenario: Decimal = 0

    private var baseSchedule: LoanSchedule {
        LoanScheduleEngine.schedule(
            principal: loan.currentBalance,
            apr: loan.apr,
            termMonths: loan.termMonths,
            monthlyPayment: loan.monthlyPayment,
            startDate: Date()
        )
    }

    private var scenarioSchedule: LoanSchedule {
        LoanScheduleEngine.schedule(
            principal: loan.currentBalance,
            apr: loan.apr,
            termMonths: loan.termMonths,
            monthlyPayment: loan.monthlyPayment,
            extraPayment: extraScenario,
            startDate: Date()
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statsRow
                extraPayBlock
                chart
                Spacer()
            }
            .padding(24)
        }
        .frame(minWidth: 720, minHeight: 580)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        }
        .onAppear { extraScenario = loan.extraPayment }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: loan.kind.systemImage).foregroundStyle(loan.kind.tint).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(loan.name).font(.title3.weight(.semibold))
                Text("\(loan.kind.displayName) · \(loan.lender)").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            stat("Balance", currency(loan.currentBalance), tint: .red)
            stat("APR", String(format: "%.3f%%", loan.apr * 100))
            stat("Payment", currency(loan.monthlyPayment))
            stat("Term", "\(loan.termMonths)mo")
            if let payoff = baseSchedule.payoffDate {
                stat("Payoff", payoff.formatted(.dateTime.month().year()))
            }
            stat("Interest left", currency(baseSchedule.totalInterest), tint: .orange)
        }
    }

    private var extraPayBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extra principal scenario").font(.callout.weight(.semibold))
            Text("Add $X/mo to principal — see how much time and interest it saves.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach([0, 100, 250, 500, 1000], id: \.self) { amt in
                    Button("$\(amt)/mo") { extraScenario = Decimal(amt) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(extraScenario == Decimal(amt) ? .blue : .gray)
                }
                Spacer()
            }
            HStack(spacing: 18) {
                stat("With extra", currency(scenarioSchedule.totalInterest), tint: .orange)
                stat("Saved", currency(scenarioSchedule.interestSaved), tint: .green)
                stat("Faster by", "\(scenarioSchedule.monthsSaved)mo", tint: .green)
                if let payoff = scenarioSchedule.payoffDate {
                    stat("New payoff", payoff.formatted(.dateTime.month().year()), tint: .green)
                }
                Spacer()
                Button("Save as loan's default") {
                    loan.extraPayment = extraScenario
                    try? modelContext.save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(extraScenario == loan.extraPayment)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Balance over time").font(.callout.weight(.semibold))
            Chart {
                ForEach(baseSchedule.lines, id: \.monthIndex) { line in
                    LineMark(
                        x: .value("Date", line.date),
                        y: .value("Balance", NSDecimalNumber(decimal: line.endingBalance).doubleValue),
                        series: .value("series", "Base")
                    )
                    .foregroundStyle(Color.secondary)
                }
                if extraScenario > 0 {
                    ForEach(scenarioSchedule.lines, id: \.monthIndex) { line in
                        LineMark(
                            x: .value("Date", line.date),
                            y: .value("Balance", NSDecimalNumber(decimal: line.endingBalance).doubleValue),
                            series: .value("series", "With extra")
                        )
                        .foregroundStyle(Color.green)
                    }
                }
            }
            .frame(height: 220)
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }
}

struct AddLoanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var lender = ""
    @State private var kind: LoanKind = .auto
    @State private var originalPrincipal = ""
    @State private var currentBalance = ""
    @State private var aprPct = ""
    @State private var termMonths = "60"
    @State private var monthlyPayment = ""
    @State private var taxDeductible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add loan").font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                field("Name", text: $name, placeholder: "2026 Civic loan")
                field("Lender", text: $lender, placeholder: "Honda Financial")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("KIND").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Kind", selection: $kind) {
                    ForEach(LoanKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu).labelsHidden()
            }
            HStack(spacing: 10) {
                field("Original principal", text: $originalPrincipal, placeholder: "25000")
                field("Current balance", text: $currentBalance, placeholder: "18000")
            }
            HStack(spacing: 10) {
                field("APR %", text: $aprPct, placeholder: "6.25")
                field("Term (months)", text: $termMonths, placeholder: "60")
                field("Monthly payment", text: $monthlyPayment, placeholder: "auto if blank")
            }
            Toggle("Interest is tax-deductible (mortgage / student / business)", isOn: $taxDeductible).toggleStyle(.switch)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || parseDecimal(currentBalance) <= 0)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
    }

    private func save() {
        let principal = parseDecimal(originalPrincipal)
        let balance = parseDecimal(currentBalance)
        let apr = (Double(aprPct) ?? 0) / 100
        let term = Int(termMonths) ?? 60
        var payment = parseDecimal(monthlyPayment)
        if payment == 0 {
            payment = LoanScheduleEngine.standardMonthlyPayment(principal: balance, apr: apr, termMonths: term)
        }
        let loan = Loan(
            name: name,
            lender: lender,
            kind: kind,
            originalPrincipal: principal > 0 ? principal : balance,
            currentBalance: balance,
            apr: apr,
            termMonths: term,
            monthlyPayment: payment,
            taxDeductible: taxDeductible
        )
        modelContext.insert(loan)
        try? modelContext.save()
        dismiss()
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
