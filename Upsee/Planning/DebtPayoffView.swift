import SwiftUI
import Charts

/// Interactive debt payoff planner over the balance sheet's liabilities.
struct DebtPayoffView: View {
    let liabilities: [BalanceSheetItem]

    @State private var strategy: PayoffStrategy = .avalanche
    @State private var extra: Double = 0

    private var debts: [DebtInput] {
        liabilities
            .filter { dbl($0.amount) > 0 }
            .map { DebtInput(id: UUID(), name: $0.name, balance: $0.amount, apr: $0.apr, minimumPayment: $0.minimumPayment) }
    }

    private var result: DebtPayoffResult {
        DebtPayoffEngine.plan(debts: debts, strategy: strategy, extraMonthlyPayment: Decimal(extra))
    }

    private var otherResult: DebtPayoffResult {
        DebtPayoffEngine.plan(debts: debts, strategy: strategy == .avalanche ? .snowball : .avalanche, extraMonthlyPayment: Decimal(extra))
    }

    var body: some View {
        if debts.isEmpty {
            EmptyHint(text: "Add liabilities with an APR and minimum payment to the balance sheet to plan a payoff.")
        } else {
            VStack(alignment: .leading, spacing: 16) {
                controls
                headline
                chart
                payoffOrder
                comparisonNote
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Strategy", selection: $strategy) {
                ForEach(PayoffStrategy.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 12) {
                Text("Extra / month")
                    .font(.callout)
                    .frame(width: 110, alignment: .leading)
                Slider(value: $extra, in: 0...3_000, step: 50)
                Text(currency(Decimal(extra)))
                    .font(.callout.monospacedDigit())
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
    }

    private var headline: some View {
        HStack(spacing: 14) {
            metric("Debt-free", debtFreeLabel, tint: result.monthsToDebtFree == nil ? .red : .green)
            metric("Total interest", currency(result.totalInterestPaid), tint: .orange)
            metric("Total owed", currency(totalOwed))
            metric("Monthly payment", currency(monthlyPayment))
        }
    }

    private var chart: some View {
        Chart {
            ForEach(result.months) { point in
                AreaMark(
                    x: .value("Month", point.month),
                    y: .value("Balance", dbl(point.totalBalance))
                )
                .foregroundStyle(LinearGradient(colors: [.accentColor.opacity(0.4), .accentColor.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                LineMark(
                    x: .value("Month", point.month),
                    y: .value("Balance", dbl(point.totalBalance))
                )
                .foregroundStyle(Color.accentColor)
            }
        }
        .frame(height: 200)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) { Text(shortCurrency(d)).font(.caption.monospacedDigit()) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 12)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let m = value.as(Int.self) { Text("Y\(m / 12)").font(.caption) }
                }
            }
        }
    }

    private var payoffOrder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Payoff order")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if result.payoffOrderNames.isEmpty {
                Text("Not retired within the horizon — increase the payment.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                FlowRow(items: Array(result.payoffOrderNames.enumerated())) { index, name in
                    HStack(spacing: 5) {
                        Text("\(index + 1)").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        Text(name).font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }
            }
        }
    }

    @ViewBuilder
    private var comparisonNote: some View {
        let mine = dbl(result.totalInterestPaid)
        let other = dbl(otherResult.totalInterestPaid)
        let savings = other - mine
        if abs(savings) > 1 {
            let better = savings > 0
            Text(better
                 ? "\(strategy.displayName.components(separatedBy: " ").first ?? "This") saves \(currency(Decimal(savings))) in interest vs. the other strategy."
                 : "The other strategy would save \(currency(Decimal(-savings))) in interest.")
                .font(.caption)
                .foregroundStyle(better ? .green : .secondary)
        }
    }

    // MARK: - Derived

    private var totalOwed: Decimal { liabilities.reduce(Decimal(0)) { $0 + $1.amount } }
    private var monthlyPayment: Decimal {
        liabilities.reduce(Decimal(0)) { $0 + $1.minimumPayment } + Decimal(extra)
    }

    private var debtFreeLabel: String {
        guard let m = result.monthsToDebtFree else { return "—" }
        if m == 0 { return "Now" }
        if m < 12 { return "\(m) mo" }
        return String(format: "%.1f yr", Double(m) / 12.0)
    }

    private func metric(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private func shortCurrency(_ d: Double) -> String {
        let a = Swift.abs(d)
        if a >= 1_000_000 { return "$\(String(format: "%.1f", d / 1_000_000))M" }
        if a >= 1_000 { return "$\(Int(d / 1_000))K" }
        return "$\(Int(d))"
    }

    private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

/// Simple wrapping row of chips.
private struct FlowRow<Item, Cell: View>: View {
    let items: [(offset: Int, element: Item)]
    @ViewBuilder let cell: (Int, Item) -> Cell

    init(items: [(offset: Int, element: Item)], @ViewBuilder cell: @escaping (Int, Item) -> Cell) {
        self.items = items
        self.cell = cell
    }

    var body: some View {
        // Deal counts are small; a simple HStack with wrapping via fixed layout is fine.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { content }
            VStack(alignment: .leading, spacing: 6) { content }
        }
    }

    private var content: some View {
        ForEach(items, id: \.offset) { pair in
            cell(pair.offset, pair.element)
        }
    }
}
