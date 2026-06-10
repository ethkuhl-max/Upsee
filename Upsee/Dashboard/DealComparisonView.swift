import SwiftUI

/// Side-by-side comparison of analyzed deals so a buyer can rank a pipeline.
/// Returns metrics (IRR, cash-on-cash) use a consistent set of default assumptions
/// so deals are compared on the same footing.
struct DealComparisonView: View {
    let deals: [DealEntity]
    let onClose: () -> Void

    private struct Column: Identifiable {
        let id: UUID
        let deal: DealEntity
        let analysis: Analysis
        let returns: ReturnsSummary
    }

    private var columns: [Column] {
        deals.compactMap { deal in
            guard let analysis = deal.savedAnalysis else { return nil }
            return Column(
                id: deal.dealID,
                deal: deal,
                analysis: analysis,
                returns: Self.defaultReturns(for: analysis)
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if columns.count < 2 {
                    ContentUnavailableView(
                        "Need two analyzed deals",
                        systemImage: "rectangle.split.3x1",
                        description: Text("Analyze and save at least two deals to compare them.")
                    )
                } else {
                    comparisonTable
                }
            }
            .navigationTitle("Compare deals")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
    }

    private var comparisonTable: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .trailing, horizontalSpacing: 18, verticalSpacing: 10) {
                headerRow
                Divider().gridCellColumns(columns.count + 1)
                textRow("Status") { Pill(text: $0.deal.status.displayName, tint: $0.deal.status.tint) }
                numericRow("Asking price", values: columns.map { dbl($0.deal.askingPrice) }, higherIsBetter: false) { currency(Decimal($0)) }
                numericRow("Normalized SDE", values: columns.map { dbl($0.analysis.normalized.normalized) }, higherIsBetter: true) { currency(Decimal($0)) }
                numericRow("Asked multiple", values: columns.map { $0.analysis.multipleReading.askedMultiple }, higherIsBetter: false) { String(format: "%.2fx", $0) }
                numericRow("DSCR at asking", values: columns.map { $0.analysis.primaryDSCR.value }, higherIsBetter: true) { String(format: "%.2f", $0) }
                numericRow("Max offer", values: columns.map { dbl($0.analysis.maxOffer) }, higherIsBetter: true) { currency(Decimal($0)) }
                numericRow("Equity in", values: columns.map { dbl($0.returns.equityInvested) }, higherIsBetter: false) { currency(Decimal($0)) }
                numericRow("Cash-on-cash Y1", values: columns.map { $0.returns.cashOnCashYear1 }, higherIsBetter: true) { percent($0) }
                numericRow("IRR (5yr)", values: columns.map { $0.returns.irr }, higherIsBetter: true) { $0.isNaN ? "—" : percent($0) }
                numericRow("Equity multiple", values: columns.map { $0.returns.equityMultiple }, higherIsBetter: true) { String(format: "%.2fx", $0) }
                textRow("Verdict") { DispositionTag(disposition: $0.analysis.verdict.disposition) }
            }
            .padding(24)
        }
    }

    private var headerRow: some View {
        GridRow {
            Text("")
                .gridColumnAlignment(.leading)
            ForEach(columns) { column in
                VStack(alignment: .leading, spacing: 2) {
                    Text(column.deal.businessName)
                        .font(.headline)
                        .lineLimit(2)
                    Text(column.analysis.deal.industry.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 150, alignment: .leading)
            }
        }
    }

    private func numericRow(
        _ label: String,
        values: [Double],
        higherIsBetter: Bool,
        format: @escaping (Double) -> String
    ) -> some View {
        let best = bestIndex(values, higherIsBetter: higherIsBetter)
        return GridRow {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                Text(format(value))
                    .font(.callout.monospacedDigit())
                    .fontWeight(idx == best ? .semibold : .regular)
                    .foregroundStyle(idx == best ? Color.green : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func textRow<Cell: View>(_ label: String, @ViewBuilder cell: @escaping (Column) -> Cell) -> some View {
        GridRow {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            ForEach(columns) { column in
                HStack {
                    Spacer(minLength: 0)
                    cell(column)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Index of the best value in a row, or -1 when every value is equal (nothing to highlight).
    private func bestIndex(_ values: [Double], higherIsBetter: Bool) -> Int {
        let valid = values.filter { !$0.isNaN }
        guard let lo = valid.min(), let hi = valid.max(), lo != hi else { return -1 }
        let target = higherIsBetter ? hi : lo
        return values.firstIndex { !$0.isNaN && $0 == target } ?? -1
    }

    private func percent(_ d: Double) -> String { String(format: "%.1f%%", d * 100) }
    private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

    static func defaultReturns(for analysis: Analysis) -> ReturnsSummary {
        let deal = analysis.deal
        let loans: [LoanTerms]
        if let financing = deal.financing, !financing.loans.isEmpty {
            loans = financing.loans
        } else {
            loans = [LoanTerms(principal: deal.askingPrice * Decimal(0.9),
                               annualRate: deal.loanTerms.annualRate,
                               amortizationYears: deal.loanTerms.amortizationYears)]
        }
        let asked = analysis.multipleReading.askedMultiple
        return ReturnsEngine.evaluate(ReturnsInputs(
            purchasePrice: deal.askingPrice,
            loans: loans,
            normalizedSDE: analysis.normalized.normalized,
            ownerSalary: 0,
            sdeGrowthRate: 0.03,
            holdYears: 5,
            exitMultiple: asked > 0 ? asked : 3.0,
            sellingCostRate: 0.05
        ))
    }
}

private struct DispositionTag: View {
    let disposition: Verdict.Disposition

    var body: some View {
        Pill(text: label, tint: tint)
    }

    private var label: String {
        switch disposition {
        case .pass: return "Pass"
        case .marginal: return "Marginal"
        case .worthPursuing: return "Pursue"
        case .worthPursuingWithConditions: return "Conditional"
        }
    }

    private var tint: Color {
        switch disposition {
        case .pass: return .red
        case .marginal: return .orange
        case .worthPursuingWithConditions: return .yellow
        case .worthPursuing: return .green
        }
    }
}
