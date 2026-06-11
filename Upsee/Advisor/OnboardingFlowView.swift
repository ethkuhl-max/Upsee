import SwiftUI
import SwiftData

/// Guided prospect onboarding: intake → risk questionnaire → review & proposal.
struct OnboardingFlowView: View {
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext

    private enum Step: Int, CaseIterable {
        case intake, risk, review
        var title: String {
            switch self {
            case .intake: return "Intake"
            case .risk: return "Risk profile"
            case .review: return "Review & proposal"
            }
        }
    }

    @State private var step: Step = .intake

    @State private var name = ""
    @State private var email = ""
    @State private var aum = ""
    @State private var fee = "1.0"
    @State private var income = ""
    @State private var expenses = ""
    @State private var cadence = 12
    @State private var answers = Array(repeating: 1, count: RiskProfileEngine.questions.count)

    private var canAdvance: Bool {
        step != .intake || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Group {
                    switch step {
                    case .intake: intakeStep
                    case .risk: riskStep
                    case .review: reviewStep
                    }
                }
                .padding(24)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ForEach(Step.allCases, id: \.self) { s in
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 22, height: 22)
                        Text("\(s.rawValue + 1)").font(.caption2.weight(.bold))
                            .foregroundStyle(s.rawValue <= step.rawValue ? .white : .secondary)
                    }
                    Text(s.title)
                        .font(.callout.weight(s == step ? .semibold : .regular))
                        .foregroundStyle(s == step ? .primary : .secondary)
                }
                if s != .review {
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1).frame(maxWidth: 30)
                }
            }
            Spacer()
        }
        .padding(20)
    }

    // MARK: - Steps

    private var intakeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prospect details").font(.title3.weight(.semibold))
            field("Name") { TextField("Jane & John Doe", text: $name).textFieldStyle(.roundedBorder) }
            field("Email") { TextField("optional", text: $email).textFieldStyle(.roundedBorder) }
            HStack(spacing: 12) {
                field("Assets to manage") { TextField("0", text: $aum).textFieldStyle(.roundedBorder).monospacedDigit() }
                field("Advisory fee (%)") { TextField("1.0", text: $fee).textFieldStyle(.roundedBorder).monospacedDigit() }
            }
            HStack(spacing: 12) {
                field("Monthly income") { TextField("0", text: $income).textFieldStyle(.roundedBorder).monospacedDigit() }
                field("Monthly expenses") { TextField("0", text: $expenses).textFieldStyle(.roundedBorder).monospacedDigit() }
            }
            field("Review cadence") {
                Picker("Cadence", selection: $cadence) {
                    ForEach([3, 6, 12], id: \.self) { Text("\($0) mo").tag($0) }
                }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 240)
            }
        }
    }

    private var riskStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Risk questionnaire").font(.title3.weight(.semibold))
            ForEach(RiskProfileEngine.questions) { q in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(q.id + 1). \(q.prompt)").font(.callout.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                            let selected = answers[q.id] == idx
                            Button { answers[q.id] = idx } label: {
                                Text(opt)
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor : Color.secondary.opacity(0.08)))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.2)))
                                    .foregroundStyle(selected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        let preview = draftClient()
        let profile = RiskProfileEngine.score(answers: answers)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Review").font(.title3.weight(.semibold))
            summaryRow("Name", name.isEmpty ? "—" : name)
            summaryRow("Assets to manage", currency(preview.aum))
            summaryRow("Advisory fee", String(format: "%.2f%% (%@/yr)", preview.feePercent * 100, currency(preview.annualFeeRevenue)))
            summaryRow("Risk profile", "\(profile.band.displayName) · \(profile.score)/100")
            summaryRow("Target allocation", "\(profile.equityPct)/\(profile.bondPct)/\(profile.cashPct) eq/bond/cash")
            Text("Creating this prospect saves them to your roster and lets you export a proposal PDF.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel", role: .cancel) { onClose() }
            Spacer()
            if step != .intake {
                Button("Back") { withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .intake } }
                    .buttonStyle(.bordered)
            }
            if step != .review {
                Button("Next") { withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .review } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdvance)
            } else {
                Button("Create prospect") { createProspect(exportProposal: false) }
                    .buttonStyle(.bordered)
                Button("Create & export proposal") { createProspect(exportProposal: true) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    // MARK: - Logic

    private func draftClient() -> Client {
        let c = Client(name: name, email: email, status: .prospect,
                       aum: dec(aum), feePercent: (Double(fee) ?? 1) / 100.0, reviewCadenceMonths: cadence)
        c.monthlyIncome = dec(income)
        c.monthlyExpenses = dec(expenses)
        c.riskAnswers = answers
        c.riskScore = RiskProfileEngine.score(answers: answers).score
        return c
    }

    private func createProspect(exportProposal: Bool) {
        let client = draftClient()
        modelContext.insert(client)
        try? modelContext.save()
        if exportProposal {
            let md = ClientReport.proposal(for: client)
            if let data = ExportService.pdfData(markdown: md) {
                ExportService.save(data, suggestedName: ExportService.safeName(client.name) + "-proposal.pdf", type: .pdf)
            }
        }
        onClose()
    }

    // MARK: - Helpers

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
        .padding(.vertical, 2)
    }

    private func dec(_ s: String) -> Decimal {
        Decimal(string: s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
    }
}
