import SwiftUI

struct AnalysisDocumentView: View {
    let analysis: Analysis
    /// Shown as a "New Deal" toolbar button when set (live analysis flow).
    var onNew: (() -> Void)? = nil
    /// Shown as a "Save to Dashboard" toolbar button when set (live analysis flow).
    var onSave: ((Analysis) -> Void)? = nil

    @State private var didSave = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                verdictHeader
                Divider()
                numbersSection
                Divider()
                ValuationFootballFieldView(analysis: analysis)
                Divider()
                addBackReviewSection
                Divider()
                brokerQuestionsSection
                Divider()
                changeMyMindSection
                DealFinancialsView(analysis: analysis)
                footer
            }
            .padding(40)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .toolbar {
            if let onSave {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(analysis)
                        didSave = true
                    } label: {
                        Label(didSave ? "Saved" : "Save to Dashboard",
                              systemImage: didSave ? "checkmark.circle.fill" : "square.and.arrow.down")
                    }
                    .disabled(didSave)
                }
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button { exportMarkdown() } label: { Label("Markdown (.md)", systemImage: "doc.plaintext") }
                    Button { exportPDF() } label: { Label("PDF", systemImage: "doc.richtext") }
                    Button { exportDealFile() } label: { Label("Deal file (.underight)", systemImage: "doc.badge.gearshape") }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            if let onNew {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNew()
                    } label: {
                        Label("New Deal", systemImage: "plus.circle")
                    }
                }
            }
        }
    }

    // MARK: - Export

    private var exportStem: String { ExportService.safeName(analysis.deal.businessName) }

    private func exportMarkdown() {
        let data = Data(AnalysisMarkdown.render(analysis).utf8)
        ExportService.save(data, suggestedName: "\(exportStem).md", type: ExportService.markdownType)
    }

    private func exportPDF() {
        guard let data = ExportService.pdfData(for: analysis) else { return }
        ExportService.save(data, suggestedName: "\(exportStem).pdf", type: .pdf)
    }

    private func exportDealFile() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(analysis) else { return }
        ExportService.save(data, suggestedName: "\(exportStem).underight", type: ExportService.underightType)
    }

    private var verdictHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DispositionPill(disposition: analysis.verdict.disposition)
                Text(analysis.deal.businessName)
                    .font(.title.weight(.semibold))
                Spacer()
            }
            Text(analysis.verdict.headline)
                .font(.system(.title3, design: .serif).weight(.medium))
                .foregroundStyle(.primary)
            Text(analysis.verdict.oneLineSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var numbersSection: some View {
        sectionShell("The numbers") {
            VStack(alignment: .leading, spacing: 10) {
                row("Asking price", currency(analysis.deal.askingPrice))
                row("Reported SDE", currency(analysis.deal.reportedSDE))
                row("Normalized SDE", currency(analysis.normalized.normalized),
                    note: analysis.normalized.sdeReduction > 0 ?
                          "−\(currency(analysis.normalized.sdeReduction)) after credibility weighting" : nil)
                row("Asked multiple",
                    String(format: "%.2fx %@", analysis.multipleReading.askedMultiple, analysis.multipleReading.basisLabel),
                    note: analysis.multipleReading.verdict.label)
                row(analysis.deal.financing == nil ? "DSCR at asking" : "DSCR on financing stack",
                    String(format: "%.2f", analysis.primaryDSCR.value),
                    note: analysis.primaryDSCR.reading.label)
                row("Max offer at \(String(format: "%.2f", analysis.deal.targetDSCR)) DSCR",
                    currency(analysis.maxOffer))

                if let financing = analysis.deal.financing, !financing.loans.isEmpty {
                    Text("Financing stack")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                    if financing.buyerEquity > 0 {
                        row("Buyer equity", currency(financing.buyerEquity))
                    }
                    ForEach(Array(financing.loans.enumerated()), id: \.offset) { index, loan in
                        row(loanLabel(index), currency(loan.principal),
                            note: String(format: "%.2f%% · %d yr", loan.annualRate * 100, loan.amortizationYears))
                    }
                }

                if !analysis.stress.isEmpty {
                    Text("Stress matrix")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                    ForEach(Array(analysis.stress.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(row.label).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", row.dscr.value))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text(row.dscr.reading.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var addBackReviewSection: some View {
        sectionShell("Skeptical review of the add-backs") {
            VStack(alignment: .leading, spacing: 14) {
                if analysis.addBackReview.items.isEmpty {
                    Text("No add-backs disclosed in the CIM.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(analysis.addBackReview.items.enumerated()), id: \.offset) { _, item in
                        addBackComment(item)
                    }
                    if let overall = analysis.addBackReview.overallNote, !overall.isEmpty {
                        Text(overall)
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                }
            }
        }
    }

    private func addBackComment(_ item: AddBackComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                VerdictPill(verdict: item.verdict)
                Text(item.label).font(.callout.weight(.medium))
                Spacer()
                ConfidenceBadge(confidence: item.confidence)
            }
            Text(item.commentary)
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.9))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private var brokerQuestionsSection: some View {
        sectionShell("Questions for the broker") {
            VStack(alignment: .leading, spacing: 12) {
                if analysis.brokerQuestions.questions.isEmpty {
                    Text("No targeted questions produced. Try regenerating.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(analysis.brokerQuestions.questions.enumerated()), id: \.offset) { index, q in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.callout.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(q.topic)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(Capsule())
                                    ConfidenceBadge(confidence: q.confidence)
                                }
                                Text(q.question)
                                    .font(.callout.weight(.medium))
                                Text(q.why)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var changeMyMindSection: some View {
        sectionShell("What would change this call") {
            VStack(alignment: .leading, spacing: 10) {
                if analysis.changeMyMind.conditions.isEmpty {
                    Text("Nothing on the table that would flip the verdict.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(analysis.changeMyMind.conditions.enumerated()), id: \.offset) { _, c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.condition).font(.callout.weight(.medium))
                            Text(c.impact).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(analysis.deal.businessName + " · " + analysis.deal.industry.displayName)
            Spacer()
            Text("Generated " + relativeDate(analysis.generatedAt))
        }
        .font(.caption.monospaced())
        .foregroundStyle(.tertiary)
        .padding(.top, 14)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionShell<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
    }

    private func loanLabel(_ index: Int) -> String {
        switch index {
        case 0: return "SBA loan"
        case 1: return "Seller note"
        default: return "Loan \(index + 1)"
        }
    }

    private func row(_ label: String, _ value: String, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).monospacedDigit().foregroundStyle(.primary)
                if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 2)
    }

    private func currency(_ d: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: d)) ?? "$0"
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct DispositionPill: View {
    let disposition: Verdict.Disposition

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch disposition {
        case .pass: return "PASS"
        case .marginal: return "MARGINAL"
        case .worthPursuing: return "WORTH PURSUING"
        case .worthPursuingWithConditions: return "CONDITIONAL"
        }
    }

    private var color: Color {
        switch disposition {
        case .pass: return .red
        case .marginal: return .orange
        case .worthPursuingWithConditions: return .yellow
        case .worthPursuing: return .green
        }
    }
}

private struct VerdictPill: View {
    let verdict: AddBackVerdict

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch verdict {
        case .accepted: return "ACCEPTED"
        case .discounted: return "DISCOUNTED"
        case .rejected: return "REJECTED"
        case .requiresVerification: return "VERIFY"
        }
    }

    private var color: Color {
        switch verdict {
        case .accepted: return .green
        case .discounted: return .yellow
        case .rejected: return .red
        case .requiresVerification: return .orange
        }
    }
}

private struct ConfidenceBadge: View {
    let confidence: Confidence

    var body: some View {
        Text(confidence.rawValue.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
