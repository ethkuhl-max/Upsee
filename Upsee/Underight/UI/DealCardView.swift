import SwiftUI

struct DealCardView: View {
    let initial: Deal
    let onAnalyze: (Deal) -> Void
    let onCancel: () -> Void

    @State private var businessName: String = ""
    @State private var industry: IndustryCategory = .other
    @State private var location: String = ""
    @State private var askingPrice: String = ""
    @State private var reportedSDE: String = ""
    @State private var addBacks: [AddBack] = []
    @State private var targetDSCR: Double = 1.25
    @State private var rate: Double = 0.115
    @State private var amortYears: Int = 10

    // Custom financing stack (SBA + seller note + buyer equity). Off → implied 100% SBA.
    @State private var useCustomFinancing = false
    @State private var buyerEquity: String = ""
    @State private var sbaAmount: String = ""
    @State private var sellerNoteAmount: String = ""
    @State private var sellerRate: Double = 0.07
    @State private var sellerTermYears: Int = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section("Business") {
                    LabeledContent("Name") {
                        TextField("Business name", text: $businessName)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Industry") {
                        Picker("Industry", selection: $industry) {
                            ForEach(IndustryCategory.allCases, id: \.self) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    LabeledContent("Location") {
                        TextField("Optional", text: $location)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                section("Headline numbers") {
                    LabeledContent("Asking price") {
                        TextField("$0", text: $askingPrice)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                    }
                    LabeledContent("Reported SDE") {
                        TextField("$0", text: $reportedSDE)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                    }
                }

                section("Add-backs") {
                    if addBacks.isEmpty {
                        Text("No add-backs disclosed in the CIM.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($addBacks) { $addBack in
                            AddBackRow(addBack: $addBack, onDelete: {
                                addBacks.removeAll { $0.id == addBack.id }
                            })
                        }
                    }
                    Button {
                        addBacks.append(AddBack(label: "New add-back", amount: 0, category: .other))
                    } label: {
                        Label("Add an add-back", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                section("Financing assumption") {
                    LabeledContent("Target DSCR") {
                        Slider(value: $targetDSCR, in: 1.0...1.75, step: 0.05) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("1.00")
                        } maximumValueLabel: {
                            Text(String(format: "%.2f", targetDSCR))
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("SBA rate") {
                        Slider(value: $rate, in: 0.07...0.15, step: 0.0025) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("7%")
                        } maximumValueLabel: {
                            Text(String(format: "%.2f%%", rate * 100))
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("Amortization (years)") {
                        Picker("Amortization", selection: $amortYears) {
                            ForEach([5, 7, 10, 15, 25], id: \.self) { years in
                                Text("\(years)").tag(years)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                section("Financing stack") {
                    Toggle("Model a custom stack (equity + seller note)", isOn: $useCustomFinancing)
                        .toggleStyle(.switch)
                    if useCustomFinancing {
                        LabeledContent("Buyer equity") {
                            TextField("$0", text: $buyerEquity)
                                .textFieldStyle(.roundedBorder)
                                .monospacedDigit()
                        }
                        LabeledContent("SBA loan amount") {
                            TextField("$0", text: $sbaAmount)
                                .textFieldStyle(.roundedBorder)
                                .monospacedDigit()
                        }
                        Text("SBA loan uses the rate and amortization above.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        LabeledContent("Seller note amount") {
                            TextField("$0", text: $sellerNoteAmount)
                                .textFieldStyle(.roundedBorder)
                                .monospacedDigit()
                        }
                        LabeledContent("Seller note rate") {
                            Slider(value: $sellerRate, in: 0...0.12, step: 0.0025) {
                                EmptyView()
                            } minimumValueLabel: {
                                Text("0%")
                            } maximumValueLabel: {
                                Text(String(format: "%.2f%%", sellerRate * 100))
                                    .monospacedDigit()
                            }
                        }
                        LabeledContent("Seller note term (years)") {
                            Picker("Seller note term", selection: $sellerTermYears) {
                                ForEach([3, 5, 7, 10], id: \.self) { y in
                                    Text("\(y)").tag(y)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        financingSummary
                    } else {
                        Text("DSCR assumes 100% of the asking price financed at the SBA terms above.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                actions
            }
            .padding(32)
        }
        .onAppear { hydrate() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confirm what Underight read")
                .font(.title2.weight(.semibold))
            Text("Sellers and brokers are inconsistent. Verify each field below before Underight gives you a verdict.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack {
            Button("Cancel", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.large)
            Spacer()
            Button {
                onAnalyze(currentDeal())
            } label: {
                Label("Analyze", systemImage: "checkmark.seal.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.top, 8)
    }

    private var financingSummary: some View {
        let sources = parseDecimal(buyerEquity) + parseDecimal(sbaAmount) + parseDecimal(sellerNoteAmount)
        let gap = parseDecimal(askingPrice) - sources
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Sources total").foregroundStyle(.secondary)
                Spacer()
                Text(currency(sources)).monospacedDigit()
            }
            .font(.callout)
            if gap > 0 {
                Text("Short of asking by \(currency(gap)) — add equity or a note.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if gap < 0 {
                Text("Exceeds asking by \(currency(-gap)).")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Fully funded against the asking price.")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func hydrate() {
        businessName = initial.businessName
        industry = initial.industry
        location = initial.location ?? ""
        askingPrice = formatDecimal(initial.askingPrice)
        reportedSDE = formatDecimal(initial.reportedSDE)
        addBacks = initial.addBacks
        targetDSCR = initial.targetDSCR
        rate = initial.loanTerms.annualRate
        amortYears = initial.loanTerms.amortizationYears

        if let financing = initial.financing, !financing.loans.isEmpty {
            useCustomFinancing = true
            buyerEquity = formatDecimal(financing.buyerEquity)
            if let sba = financing.loans.first {
                sbaAmount = formatDecimal(sba.principal)
            }
            if financing.loans.count > 1 {
                let note = financing.loans[1]
                sellerNoteAmount = formatDecimal(note.principal)
                sellerRate = note.annualRate
                sellerTermYears = note.amortizationYears
            }
        } else {
            // Sensible default for the moment the user flips the toggle on.
            sbaAmount = formatDecimal(initial.askingPrice)
        }
    }

    private func currentDeal() -> Deal {
        Deal(
            id: initial.id,
            businessName: businessName,
            industry: industry,
            location: location.isEmpty ? nil : location,
            askingPrice: parseDecimal(askingPrice),
            reportedSDE: parseDecimal(reportedSDE),
            grossRevenue: initial.grossRevenue,
            addBacks: addBacks,
            loanTerms: LoanTerms(principal: 0, annualRate: rate, amortizationYears: amortYears),
            financing: currentFinancing(),
            targetDSCR: targetDSCR,
            sourcePDFPath: initial.sourcePDFPath,
            createdAt: initial.createdAt,
            updatedAt: Date()
        )
    }

    /// Builds the financing stack from the form, or nil when the user left it implied.
    private func currentFinancing() -> FinancingScenario? {
        guard useCustomFinancing else { return nil }
        var loans: [LoanTerms] = []
        let sba = parseDecimal(sbaAmount)
        if sba > 0 {
            loans.append(LoanTerms(principal: sba, annualRate: rate, amortizationYears: amortYears))
        }
        let note = parseDecimal(sellerNoteAmount)
        if note > 0 {
            loans.append(LoanTerms(principal: note, annualRate: sellerRate, amortizationYears: sellerTermYears))
        }
        guard !loans.isEmpty else { return nil }
        return FinancingScenario(label: "Custom", loans: loans, buyerEquity: parseDecimal(buyerEquity))
    }
}

private struct AddBackRow: View {
    @Binding var addBack: AddBack
    let onDelete: () -> Void

    @State private var amountText: String = ""
    @State private var credibilityValue: Double = 0.5

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Label", text: $addBack.label)
                    .textFieldStyle(.roundedBorder)
                Picker("Category", selection: $addBack.category) {
                    ForEach(AddBackCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                TextField("Amount", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(maxWidth: 140)
                    .onChange(of: amountText) { _, new in
                        addBack.amount = parseDecimal(new)
                    }
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Text("Credibility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $credibilityValue, in: 0...1, step: 0.05)
                    .onChange(of: credibilityValue) { _, new in
                        addBack.credibility = new
                    }
                Text(String(format: "%.0f%%", credibilityValue * 100))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
        .onAppear {
            amountText = formatDecimal(addBack.amount)
            credibilityValue = addBack.credibility
        }
    }
}

private func parseDecimal(_ s: String) -> Decimal {
    let cleaned = s.replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: ",", with: "")
        .trimmingCharacters(in: .whitespaces)
    return Decimal(string: cleaned) ?? 0
}

private func formatDecimal(_ d: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSDecimalNumber(decimal: d)) ?? "0"
}
