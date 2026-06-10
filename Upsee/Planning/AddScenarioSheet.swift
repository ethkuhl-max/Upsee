import SwiftUI
import SwiftData

struct AddScenarioSheet: View {
    let baseIncome: Decimal
    let baseExpenses: Decimal
    let baseBalance: Decimal

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \AppEntity.name) private var apps: [AppEntity]
    @Query(sort: \JobEntity.title) private var jobs: [JobEntity]

    @State private var name = ""
    @State private var summary = ""
    @State private var overrideIncome = false
    @State private var incomeText = ""
    @State private var overrideExpenses = false
    @State private var expensesText = ""
    @State private var overrideBalance = false
    @State private var balanceText = ""
    @State private var monthsAhead = 24

    // Per-entity overrides, keyed by entity name/title.
    @State private var appIncluded: [String: Bool] = [:]
    @State private var appValue: [String: String] = [:]
    @State private var jobIncluded: [String: Bool] = [:]
    @State private var jobValue: [String: String] = [:]

    private var canSave: Bool { !name.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Scenario").font(.title3.weight(.semibold))
            Text("Layer overrides on top of your current entities to model a what-if.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Name", text: $name, placeholder: "Quit job in 6 months / All-in on apps")
                    field("Summary", text: $summary, placeholder: "Optional one-line description")

                    overrideRow(label: "Override total monthly income", toggle: $overrideIncome, text: $incomeText, baseValue: baseIncome)
                    overrideRow(label: "Override monthly expenses", toggle: $overrideExpenses, text: $expensesText, baseValue: baseExpenses)
                    overrideRow(label: "Override starting balance", toggle: $overrideBalance, text: $balanceText, baseValue: baseBalance)

                    Stepper("Project \(monthsAhead) months ahead", value: $monthsAhead, in: 3...60, step: 3)

                    if !overrideIncome && (!apps.isEmpty || !jobs.isEmpty) {
                        perEntitySection
                    }
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var perEntitySection: some View {
        DisclosureGroup("Per-entity overrides") {
            VStack(alignment: .leading, spacing: 10) {
                if !apps.isEmpty {
                    Text("APPS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(apps) { app in
                        entityRow(
                            name: app.name,
                            base: app.monthlyRevenue,
                            included: binding($appIncluded, app.name, default: true),
                            value: binding($appValue, app.name)
                        )
                    }
                }
                if !jobs.isEmpty {
                    Text("JOBS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                    ForEach(jobs) { job in
                        entityRow(
                            name: job.title,
                            base: job.monthlyCompensation,
                            included: binding($jobIncluded, job.title, default: job.status == .active),
                            value: binding($jobValue, job.title)
                        )
                    }
                }
                Text("Toggle off to remove an entity's income; enter a value to override it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 6)
        }
    }

    private func entityRow(name: String, base: Decimal, included: Binding<Bool>, value: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: included).toggleStyle(.switch).labelsHidden()
            Text(name).font(.callout).lineLimit(1)
            Spacer()
            TextField(currency(base), text: value)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(width: 120)
                .disabled(!included.wrappedValue)
        }
    }

    private func save() {
        let scenario = ScenarioEntity(
            name: name,
            summary: summary,
            monthlyIncomeOverride: overrideIncome ? parseDecimal(incomeText) : nil,
            monthlyExpensesOverride: overrideExpenses ? parseDecimal(expensesText) : nil,
            startingBalanceOverride: overrideBalance ? parseDecimal(balanceText) : nil,
            monthsAhead: monthsAhead,
            startsAt: Date()
        )
        if !overrideIncome {
            scenario.entityOverrides = buildOverrides()
        }
        modelContext.insert(scenario)
        try? modelContext.save()
        dismiss()
    }

    private func buildOverrides() -> [ScenarioEntityOverride] {
        var result: [ScenarioEntityOverride] = []
        for app in apps {
            let inc = appIncluded[app.name] ?? true
            let text = appValue[app.name] ?? ""
            let val: Decimal? = text.isEmpty ? nil : parseDecimal(text)
            if !inc || val != nil {
                result.append(.init(kind: .app, targetName: app.name, included: inc, monthlyValueOverride: val))
            }
        }
        for job in jobs {
            let defaultIncluded = job.status == .active
            let inc = jobIncluded[job.title] ?? defaultIncluded
            let text = jobValue[job.title] ?? ""
            let val: Decimal? = text.isEmpty ? nil : parseDecimal(text)
            if inc != defaultIncluded || val != nil {
                result.append(.init(kind: .job, targetName: job.title, included: inc, monthlyValueOverride: val))
            }
        }
        return result
    }

    // MARK: - Helpers

    private func binding(_ dict: Binding<[String: Bool]>, _ key: String, default defaultValue: Bool) -> Binding<Bool> {
        Binding(get: { dict.wrappedValue[key] ?? defaultValue }, set: { dict.wrappedValue[key] = $0 })
    }

    private func binding(_ dict: Binding<[String: String]>, _ key: String) -> Binding<String> {
        Binding(get: { dict.wrappedValue[key] ?? "" }, set: { dict.wrappedValue[key] = $0 })
    }

    @ViewBuilder
    private func overrideRow(label: String, toggle: Binding<Bool>, text: Binding<String>, baseValue: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(label, isOn: toggle).toggleStyle(.switch)
            HStack {
                TextField(currency(baseValue), text: text)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!toggle.wrappedValue)
                Text("base: \(currency(baseValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}
