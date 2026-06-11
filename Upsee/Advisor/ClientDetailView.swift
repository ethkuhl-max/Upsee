import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ClientDetailView: View {
    @Bindable var client: Client

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingQuestionnaire = false
    @State private var addingLineItem = false
    @State private var addingGoal = false
    @State private var newMeeting = ""
    @State private var statusMessage: String?

    private var monthlySurplus: Decimal { max(0, client.monthlyIncome - client.monthlyExpenses) }

    private var netWorth: NetWorthSummary { NetWorthEngine.summarize(client.lineItems) }

    private var health: FinancialHealth {
        let liquid = client.lineItems
            .filter { $0.isAsset && ($0.category.lowercased().contains("cash") || $0.category.lowercased().contains("invest")) }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return FinancialHealthEngine.assess(FinancialHealthInputs(
            monthlyIncome: client.monthlyIncome,
            monthlyExpenses: client.monthlyExpenses,
            liquidSavings: liquid > 0 ? liquid : netWorth.totalAssets,
            totalAssets: netWorth.totalAssets,
            totalLiabilities: netWorth.totalLiabilities,
            monthlyDebtPayments: 0,
            largestIncomeShare: 0.5
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileSection
                riskSection
                balanceSheetSection
                goalsSection
                healthSection
                meetingsSection
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle(client.name)
        .toolbar { toolbar }
        .sheet(isPresented: $showingQuestionnaire) {
            RiskQuestionnaireView(client: client).frame(minWidth: 520, minHeight: 520)
        }
        .sheet(isPresented: $addingLineItem) {
            AddLineItemSheet(client: client).frame(minWidth: 420, minHeight: 320)
        }
        .sheet(isPresented: $addingGoal) {
            AddClientGoalSheet(client: client).frame(minWidth: 420, minHeight: 320)
        }
        .alert("Export", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
            Button("OK") { statusMessage = nil }
        } message: { Text(statusMessage ?? "") }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { exportPlan(pdf: true) } label: { Label("Plan Summary (PDF)", systemImage: "doc.richtext") }
                Button { exportPlan(pdf: false) } label: { Label("Plan Summary (Markdown)", systemImage: "doc.plaintext") }
                Divider()
                Button { exportIPS(pdf: true) } label: { Label("IPS (PDF)", systemImage: "doc.text") }
                Button { exportIPS(pdf: false) } label: { Label("IPS (Markdown)", systemImage: "doc.plaintext") }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
        }
        ToolbarItem(placement: .destructiveAction) {
            Button(role: .destructive) {
                modelContext.delete(client)
                try? modelContext.save()
                dismiss()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        section("Profile") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Status", selection: $client.status) {
                    ForEach(ClientStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)

                LabeledContent("Email") { TextField("optional", text: $client.email).textFieldStyle(.roundedBorder).frame(maxWidth: 260) }
                LabeledContent("AUM") { TextField("0", value: $client.aum, format: .number).textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 160) }
                LabeledContent("Advisory fee %") { TextField("1.0", value: feePercentBinding, format: .number).textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 100) }
                LabeledContent("Monthly income") { TextField("0", value: $client.monthlyIncome, format: .number).textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 160) }
                LabeledContent("Monthly expenses") { TextField("0", value: $client.monthlyExpenses, format: .number).textFieldStyle(.roundedBorder).monospacedDigit().frame(maxWidth: 160) }
                LabeledContent("Review cadence") {
                    Picker("Cadence", selection: $client.reviewCadenceMonths) {
                        ForEach([3, 6, 12], id: \.self) { Text("\($0) mo").tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 220)
                }
                HStack {
                    if let next = client.nextReviewDate {
                        Text("Next review: \(dateString(next))").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No review logged yet.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Log review today") {
                        client.lastReviewDate = Date()
                        client.meetings.append(ClientMeeting(summary: "Portfolio review"))
                        try? modelContext.save()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var feePercentBinding: Binding<Double> {
        Binding(get: { client.feePercent * 100 }, set: { client.feePercent = $0 / 100 })
    }

    // MARK: - Risk

    private var riskSection: some View {
        section("Risk profile") {
            if client.riskAnswers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No risk profile yet.").font(.callout).foregroundStyle(.secondary)
                    Button { showingQuestionnaire = true } label: { Label("Run questionnaire", systemImage: "list.bullet.clipboard") }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                let profile = RiskProfileEngine.score(answers: client.riskAnswers)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Pill(text: profile.band.displayName, tint: .blue)
                        Text("\(profile.score)/100").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button("Retake") { showingQuestionnaire = true }.buttonStyle(.bordered)
                    }
                    HStack(spacing: 14) {
                        allocationChip("Equities", profile.equityPct, .green)
                        allocationChip("Bonds", profile.bondPct, .blue)
                        allocationChip("Cash", profile.cashPct, .gray)
                    }
                }
            }
        }
    }

    private func allocationChip(_ label: String, _ pct: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(pct)%").font(.title3.monospacedDigit().weight(.semibold)).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.1)))
    }

    // MARK: - Balance sheet

    private var balanceSheetSection: some View {
        section("Balance sheet") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    metric("Net worth", currency(netWorth.netWorth), netWorth.netWorth >= 0 ? .green : .red)
                    metric("Assets", currency(netWorth.totalAssets))
                    metric("Liabilities", currency(netWorth.totalLiabilities), .orange)
                }
                ForEach(client.lineItems) { item in
                    HStack {
                        Image(systemName: item.isAsset ? "plus.circle" : "minus.circle")
                            .foregroundStyle(item.isAsset ? .green : .orange)
                        Text(item.name).font(.callout)
                        Spacer()
                        Text(currency(item.amount)).font(.callout.monospacedDigit())
                        Button(role: .destructive) {
                            client.lineItems.removeAll { $0.id == item.id }
                            try? modelContext.save()
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
                }
                Button { addingLineItem = true } label: { Label("Add asset / liability", systemImage: "plus") }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        section("Goals") {
            VStack(alignment: .leading, spacing: 10) {
                if client.goals.isEmpty {
                    Text("No goals yet — add retirement, college, or a home down payment.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(client.goals) { goal in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(goal.name).font(.callout.weight(.medium))
                            Spacer()
                            Text("\(currency(goal.currentAmount)) / \(currency(goal.targetAmount))")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                client.goals.removeAll { $0.id == goal.id }
                                try? modelContext.save()
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                        ProgressView(value: goal.progress)
                        Text(projectionLabel(for: goal))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
                }
                Button { addingGoal = true } label: { Label("Add goal", systemImage: "plus") }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func projectionLabel(for goal: ClientGoal) -> String {
        if goal.progress >= 1 { return "Funded" }
        guard let date = goal.projectedHitDate(monthlyContribution: monthlySurplus) else {
            return monthlySurplus > 0 ? "On track" : "No surplus to fund this goal"
        }
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return "Projected \(f.string(from: date)) at current surplus"
    }

    // MARK: - Health

    private var healthSection: some View {
        section("Financial health") {
            let h = health
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(h.grade).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.blue)
                    Text("\(h.overall)/100").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                }
                ForEach(h.subscores) { sub in
                    HStack(spacing: 8) {
                        Text(sub.name).font(.caption).lineLimit(1).frame(width: 140, alignment: .leading)
                        ProgressView(value: Double(sub.score) / 100)
                        Text("\(sub.score)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Meetings

    private var meetingsSection: some View {
        section("Meeting log") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(client.meetings.sorted { $0.date > $1.date }) { meeting in
                    HStack(alignment: .top, spacing: 8) {
                        Text(dateString(meeting.date)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                        Text(meeting.summary).font(.callout)
                        Spacer()
                    }
                }
                HStack {
                    TextField("Log a note…", text: $newMeeting).textFieldStyle(.roundedBorder).onSubmit(addMeeting)
                    Button(action: addMeeting) { Image(systemName: "plus") }
                        .disabled(newMeeting.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addMeeting() {
        let text = newMeeting.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        client.meetings.append(ClientMeeting(summary: text))
        try? modelContext.save()
        newMeeting = ""
    }

    // MARK: - Export

    private func exportPlan(pdf: Bool) {
        let md = ClientReport.planSummary(for: client)
        let stem = ExportService.safeName(client.name) + "-plan"
        if pdf {
            guard let data = ExportService.pdfData(markdown: md) else { return }
            if ExportService.save(data, suggestedName: stem + ".pdf", type: .pdf) { statusMessage = "Saved plan summary PDF." }
        } else {
            ExportService.save(Data(md.utf8), suggestedName: stem + ".md", type: ExportService.markdownType)
        }
    }

    private func exportIPS(pdf: Bool) {
        let md = ClientReport.investmentPolicyStatement(for: client)
        let stem = ExportService.safeName(client.name) + "-IPS"
        if pdf {
            guard let data = ExportService.pdfData(markdown: md) else { return }
            if ExportService.save(data, suggestedName: stem + ".pdf", type: .pdf) { statusMessage = "Saved IPS PDF." }
        } else {
            ExportService.save(Data(md.utf8), suggestedName: stem + ".md", type: ExportService.markdownType)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }

    private func metric(_ label: String, _ value: String, _ tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }
}

private struct RiskQuestionnaireView: View {
    @Bindable var client: Client
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var answers: [Int]

    init(client: Client) {
        self.client = client
        let count = RiskProfileEngine.questions.count
        let existing = client.riskAnswers
        _answers = State(initialValue: existing.count == count ? existing : Array(repeating: 1, count: count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Risk questionnaire").font(.title3.weight(.semibold))
                Text("Select the answer that best describes this client's situation.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(RiskProfileEngine.questions) { q in
                        questionBlock(q)
                    }
                }
                .padding(24)
            }

            Divider()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                let preview = RiskProfileEngine.score(answers: answers)
                HStack(spacing: 6) {
                    Text(preview.band.displayName).font(.caption.weight(.semibold)).foregroundStyle(.blue)
                    Text("·").font(.caption).foregroundStyle(.secondary)
                    Text("\(preview.score)/100").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Button("Save") {
                    client.riskAnswers = answers
                    client.riskScore = preview.score
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }

    /// Question with a 2-column grid of selectable chips — handles long option text cleanly.
    private func questionBlock(_ q: RiskQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(q.id + 1).")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(q.prompt)
                    .font(.callout.weight(.semibold))
            }
            let cols = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                    let selected = answers[q.id] == idx
                    Button {
                        answers[q.id] = idx
                    } label: {
                        Text(opt)
                            .font(.callout)
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selected ? Color.accentColor : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.2))
                            )
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AddLineItemSheet: View {
    @Bindable var client: Client
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var amount = ""
    @State private var isAsset = true
    @State private var category = "Cash"

    private let categories = ["Cash", "Investments", "Retirement", "Real estate", "Other", "Mortgage", "Loan", "Credit card"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add line item").font(.title3.weight(.semibold))
            Picker("Type", selection: $isAsset) {
                Text("Asset").tag(true); Text("Liability").tag(false)
            }.pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Brokerage, mortgage…", text: $name).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Category").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().pickerStyle(.menu)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(isAsset ? "Value" : "Balance owed").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField("0", text: $amount).textFieldStyle(.roundedBorder).monospacedDigit()
            }
            Spacer()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Add") {
                    let item = ClientLineItem(name: name, amount: Decimal(string: amount.filter { $0.isNumber || $0 == "." }) ?? 0, isAsset: isAsset, category: category)
                    client.lineItems.append(item)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AddClientGoalSheet: View {
    @Bindable var client: Client
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var target = ""
    @State private var current = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add goal").font(.title3.weight(.semibold))
            field("Name") { TextField("Retirement, college, home…", text: $name).textFieldStyle(.roundedBorder) }
            field("Target amount") { TextField("0", text: $target).textFieldStyle(.roundedBorder).monospacedDigit() }
            field("Current amount") { TextField("0", text: $current).textFieldStyle(.roundedBorder).monospacedDigit() }
            Toggle("Set a target date", isOn: $hasTargetDate).toggleStyle(.switch)
            if hasTargetDate {
                DatePicker("Target date", selection: $targetDate, displayedComponents: .date).labelsHidden()
            }
            Spacer()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Add") {
                    let goal = ClientGoal(name: name, targetAmount: dec(target), currentAmount: dec(current),
                                          targetDate: hasTargetDate ? targetDate : nil)
                    client.goals.append(goal)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func dec(_ s: String) -> Decimal {
        Decimal(string: s.filter { $0.isNumber || $0 == "." }) ?? 0
    }
}
