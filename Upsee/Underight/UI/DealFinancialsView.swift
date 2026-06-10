import SwiftUI
import Charts

/// Interactive post-acquisition financials layered onto the underwriting report.
/// All assumptions are live `@State` — the buyer dials them and every figure
/// recomputes instantly (no LLM round-trip). Nothing here is persisted.
struct DealFinancialsView: View {
    let analysis: Analysis

    @State private var downPaymentPct: Double = 0.10
    @State private var ownerSalary: Double = 0
    @State private var sdeGrowth: Double = 0.03
    @State private var holdYears: Int = 5
    @State private var exitMultiple: Double = 3.0

    @State private var nwcPegPct: Double = 0.10
    @State private var tangibleAssetPct: Double = 0.20
    @State private var taxRate: Double = 0.30

    private var deal: Deal { analysis.deal }
    private var normalizedSDE: Decimal { analysis.normalized.normalized }

    /// Use the explicit financing stack if the buyer modeled one; otherwise synthesize a
    /// single SBA loan from the down-payment slider.
    private var loans: [LoanTerms] {
        if let financing = deal.financing, !financing.loans.isEmpty {
            return financing.loans
        }
        let principal = deal.askingPrice * Decimal(1 - downPaymentPct)
        return [LoanTerms(principal: principal, annualRate: deal.loanTerms.annualRate, amortizationYears: deal.loanTerms.amortizationYears)]
    }

    private var hasCustomStack: Bool {
        if let financing = deal.financing { return !financing.loans.isEmpty }
        return false
    }

    private var financedPrincipal: Decimal {
        loans.reduce(Decimal(0)) { $0 + $1.principal }
    }

    private var returns: ReturnsSummary {
        ReturnsEngine.evaluate(ReturnsInputs(
            purchasePrice: deal.askingPrice,
            loans: loans,
            normalizedSDE: normalizedSDE,
            ownerSalary: Decimal(ownerSalary),
            sdeGrowthRate: sdeGrowth,
            holdYears: holdYears,
            exitMultiple: exitMultiple,
            sellingCostRate: 0.05
        ))
    }

    private var amortization: AmortizationSchedule {
        AmortizationEngine.schedule(for: FinancingScenario(label: "stack", loans: loans, buyerEquity: 0))
    }

    private var breakEven: BreakEven {
        BreakEvenEngine.analyze(
            normalizedSDE: normalizedSDE,
            scenario: FinancingScenario(label: "stack", loans: loans, buyerEquity: 0)
        )
    }

    private var grid: SensitivityGrid {
        SensitivityEngine.grid(
            normalizedSDE: normalizedSDE,
            principal: financedPrincipal,
            amortizationYears: deal.loanTerms.amortizationYears
        )
    }

    private var metrics: DealMetrics {
        let r = returns
        return DealMetricsEngine.compute(DealMetricsInputs(
            purchasePrice: deal.askingPrice,
            normalizedSDE: normalizedSDE,
            grossRevenue: deal.grossRevenue,
            financedPrincipal: financedPrincipal,
            equityInvested: r.equityInvested,
            annualFreeCashFlow: r.proForma.first?.freeCashFlow ?? 0,
            workingCapitalPegPct: nwcPegPct,
            tangibleAssetPct: tangibleAssetPct,
            taxRate: taxRate
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Divider()
            returnsSection
            Divider()
            amortizationSection
            Divider()
            breakEvenSection
            Divider()
            deeperMetricsSection
            Divider()
            sensitivityGridSection
        }
        .onAppear {
            // Seed the exit multiple from the asked multiple only when it's SDE-based
            // (the returns model is SDE-based; a revenue multiple wouldn't apply).
            let asked = analysis.multipleReading.askedMultiple
            if asked > 0, asked.isFinite, analysis.multipleReading.usedRevenueBasis != true {
                exitMultiple = (asked * 100).rounded() / 100
            }
        }
    }

    // MARK: - Returns & exit

    private var returnsSection: some View {
        section("Returns & exit") {
            VStack(alignment: .leading, spacing: 16) {
                assumptionsControls

                let r = returns
                HStack(spacing: 14) {
                    bigMetric("Equity in", currency(r.equityInvested))
                    bigMetric("Cash-on-cash Y1", percent(r.cashOnCashYear1), tint: tint(forReturn: r.cashOnCashYear1))
                    bigMetric("IRR", r.irr.isNaN ? "—" : percent(r.irr), tint: tint(forReturn: r.irr.isNaN ? 0 : r.irr))
                    bigMetric("Equity multiple", String(format: "%.2fx", r.equityMultiple))
                }

                proFormaTable(r)
                exitBlock(r)
            }
        }
    }

    private var assumptionsControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasCustomStack {
                Text("Using the financing stack from the review screen (equity \(currency(deal.askingPrice - financedPrincipal))).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                sliderRow("Down payment", value: String(format: "%.0f%%", downPaymentPct * 100)) {
                    Slider(value: $downPaymentPct, in: 0.05...0.50, step: 0.05)
                }
            }
            sliderRow("Owner salary", value: currency(Decimal(ownerSalary))) {
                Slider(value: $ownerSalary, in: 0...300_000, step: 5_000)
            }
            sliderRow("SDE growth / yr", value: String(format: "%.0f%%", sdeGrowth * 100)) {
                Slider(value: $sdeGrowth, in: -0.10...0.25, step: 0.01)
            }
            sliderRow("Exit multiple", value: String(format: "%.2fx", exitMultiple)) {
                Slider(value: $exitMultiple, in: 1.0...6.0, step: 0.25)
            }
            LabeledContent("Hold period") {
                Picker("Hold period", selection: $holdYears) {
                    ForEach([3, 5, 7, 10], id: \.self) { y in
                        Text("\(y) yr").tag(y)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
    }

    private func proFormaTable(_ r: ReturnsSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pro forma")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Year").gridColumnAlignment(.leading)
                    Text("SDE")
                    Text("Debt svc")
                    Text("Free cash")
                    Text("Cumulative")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                ForEach(r.proForma) { row in
                    GridRow {
                        Text("Y\(row.year)").gridColumnAlignment(.leading)
                        Text(currency(row.sde))
                        Text(currency(row.debtService))
                        Text(currency(row.freeCashFlow))
                            .foregroundStyle(row.freeCashFlow >= 0 ? Color.primary : Color.red)
                        Text(currency(row.cumulativeCashFlow))
                    }
                    .font(.callout.monospacedDigit())
                }
            }
        }
    }

    private func exitBlock(_ r: ReturnsSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Exit in year \(holdYears)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            row("Enterprise value", currency(r.exitEnterpriseValue),
                note: String(format: "%.2fx exit SDE", exitMultiple))
            row("Less: debt payoff", "−" + currency(r.exitDebtPayoff))
            row("Equity proceeds (net of 5% costs)", currency(r.exitEquityProceeds))
            row("Total profit over hold", currency(r.totalProfit),
                note: r.totalProfit >= 0 ? nil : "Loses money under these assumptions")
        }
    }

    // MARK: - Amortization

    private var amortizationSection: some View {
        section("Debt amortization & equity build") {
            VStack(alignment: .leading, spacing: 10) {
                if amortization.months.isEmpty {
                    Text("No debt modeled — this is an all-cash purchase.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    amortizationChart
                    HStack(spacing: 24) {
                        bigMetric("Financed", currency(amortization.totalPrincipal))
                        bigMetric("Total interest", currency(amortization.totalInterest))
                        bigMetric("Payoff", "\(payoffYears) yr")
                    }
                }
            }
        }
    }

    private var payoffYears: Int {
        (amortization.months.count + 11) / 12
    }

    private var amortizationChart: some View {
        let total = NSDecimalNumber(decimal: amortization.totalPrincipal).doubleValue
        return Chart {
            ForEach(amortization.months, id: \.month) { m in
                let balance = NSDecimalNumber(decimal: m.balance).doubleValue
                LineMark(
                    x: .value("Month", m.month),
                    y: .value("Amount", balance),
                    series: .value("Series", "Loan balance")
                )
                .foregroundStyle(Color.red)
                LineMark(
                    x: .value("Month", m.month),
                    y: .value("Amount", total - balance),
                    series: .value("Series", "Equity built")
                )
                .foregroundStyle(Color.green)
            }
        }
        .frame(height: 200)
        .chartForegroundStyleScale(["Loan balance": Color.red, "Equity built": Color.green])
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(shortCurrency(d)).font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 12)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let m = value.as(Int.self) {
                        Text("Y\(m / 12)").font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Deeper metrics

    private var deeperMetricsSection: some View {
        section("Deeper metrics") {
            let m = metrics
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow("NWC peg (% rev)", value: String(format: "%.0f%%", nwcPegPct * 100)) {
                        Slider(value: $nwcPegPct, in: 0...0.30, step: 0.01)
                    }
                    sliderRow("Tangible assets", value: String(format: "%.0f%%", tangibleAssetPct * 100)) {
                        Slider(value: $tangibleAssetPct, in: 0...1.0, step: 0.05)
                    }
                    sliderRow("Tax rate", value: String(format: "%.0f%%", taxRate * 100)) {
                        Slider(value: $taxRate, in: 0...0.50, step: 0.01)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))

                HStack(spacing: 14) {
                    bigMetric("Debt yield", m.debtYield.isInfinite ? "—" : percent(m.debtYield),
                              tint: m.debtYield >= 0.10 ? .green : (m.debtYield >= 0.08 ? .orange : .red))
                    bigMetric("ROIC", percent(m.returnOnInvestedCapital))
                    bigMetric("Equity payback", m.equityPaybackYears.map { String(format: "%.1f yr", $0) } ?? "—")
                }
                row("Working capital peg", currency(m.workingCapitalPeg),
                    note: "Cash you'll need to fund operations day one")
                row("§197 goodwill", currency(m.goodwill),
                    note: "Amortized straight-line over 15 years")
                row("Annual amortization", currency(m.annualGoodwillAmortization))
                row("Annual tax shield", currency(m.annualGoodwillTaxShield),
                    note: "Cash taxes deferred by the amortization deduction")
            }
        }
    }

    // MARK: - Break-even

    private var breakEvenSection: some View {
        section("Break-even cushion") {
            VStack(alignment: .leading, spacing: 12) {
                Text("How far normalized SDE can fall before the deal stops penciling.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                cushionBar(
                    label: "To lender floor (DSCR 1.25)",
                    fraction: breakEven.sdeCushionToLenderFloor,
                    floorSDE: breakEven.lenderFloorSDE,
                    tint: .orange
                )
                cushionBar(
                    label: "To break-even (DSCR 1.00)",
                    fraction: breakEven.sdeCushionToBreakEven,
                    floorSDE: breakEven.breakEvenSDE,
                    tint: .red
                )
            }
        }
    }

    private func cushionBar(label: String, fraction: Double, floorSDE: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(fraction > 0 ? String(format: "%.0f%% headroom", fraction * 100) : "Already below")
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(fraction > 0 ? tint : .red)
            }
            ProgressView(value: max(0, min(1, fraction)))
                .tint(tint)
            Text("Floor SDE \(currency(floorSDE)) vs normalized \(currency(normalizedSDE))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 2-variable sensitivity

    private var sensitivityGridSection: some View {
        section("Sensitivity grid — DSCR by SDE × rate") {
            VStack(alignment: .leading, spacing: 8) {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        Text("SDE \\ Rate")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        ForEach(grid.rates, id: \.self) { rate in
                            Text(String(format: "%.0f%%", rate * 100))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(Array(grid.sdeFactors.enumerated()), id: \.offset) { rowIndex, factor in
                        GridRow {
                            Text(String(format: "%.0f%%", factor * 100))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .leading)
                            ForEach(Array(grid.cells[rowIndex].enumerated()), id: \.offset) { _, cell in
                                Text(String(format: "%.2f", cell.value))
                                    .font(.caption.monospacedDigit())
                                    .frame(maxWidth: .infinity, minHeight: 26)
                                    .background(color(for: cell.reading).opacity(0.22))
                                    .foregroundStyle(color(for: cell.reading))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                    }
                }
                Text("Rows = normalized SDE held at this fraction · columns = blended rate over a \(deal.loanTerms.amortizationYears)-yr amortization.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }

    private func sliderRow<S: View>(_ label: String, value: String, @ViewBuilder _ slider: () -> S) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.callout)
                .frame(width: 130, alignment: .leading)
            slider()
            Text(value)
                .font(.callout.monospacedDigit())
                .frame(width: 80, alignment: .trailing)
        }
    }

    private func bigMetric(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private func row(_ label: String, _ value: String, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).monospacedDigit()
                if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 1)
    }

    private func percent(_ d: Double) -> String { String(format: "%.1f%%", d * 100) }

    private func shortCurrency(_ d: Double) -> String {
        let abs = Swift.abs(d)
        let sign = d < 0 ? "-" : ""
        if abs >= 1_000_000 { return "\(sign)$\(String(format: "%.1f", abs / 1_000_000))M" }
        if abs >= 1_000 { return "\(sign)$\(Int(abs / 1_000))K" }
        return "\(sign)$\(Int(abs))"
    }

    private func tint(forReturn d: Double) -> Color {
        switch d {
        case 0.20...: return .green
        case 0.10..<0.20: return .blue
        case 0..<0.10: return .orange
        default: return .red
        }
    }

    private func color(for reading: DSCRReading) -> Color {
        switch reading {
        case .healthy: return .green
        case .adequate: return .blue
        case .marginal: return .orange
        case .underwater: return .red
        }
    }
}
