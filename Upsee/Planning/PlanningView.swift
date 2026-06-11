import SwiftUI
import SwiftData

struct PlanningView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppEntity.updatedAt, order: .reverse) private var apps: [AppEntity]
    @Query(sort: \JobEntity.updatedAt, order: .reverse) private var jobs: [JobEntity]
    @Query private var personal: [PersonalEntity]
    @Query(sort: \GoalEntity.updatedAt, order: .reverse) private var goals: [GoalEntity]
    @Query(sort: \ScenarioEntity.updatedAt, order: .reverse) private var scenarios: [ScenarioEntity]
    @Query(sort: \BalanceSheetItem.createdAt) private var balanceSheetItems: [BalanceSheetItem]

    @State private var addingGoal = false
    @State private var addingScenario = false
    @State private var taxReminderSet = false

    private var personalEntity: PersonalEntity? { personal.first }

    private var netWorth: NetWorthSummary { NetWorthEngine.summarize(balanceSheetItems) }

    /// Seed the wealth projection from net worth when a balance sheet exists, else cash savings.
    private var wealthStartingBalance: Decimal {
        balanceSheetItems.isEmpty ? startingBalance : netWorth.netWorth
    }

    private var baseIncome: Decimal {
        CashFlowEngine.aggregateMonthlyIncome(jobs: jobs, apps: apps, personal: personalEntity)
    }

    private var baseExpenses: Decimal {
        CashFlowEngine.aggregateMonthlyExpenses(personal: personalEntity)
    }

    private var startingBalance: Decimal {
        personalEntity?.currentSavings ?? 0
    }

    private var projection: CashFlowProjection {
        CashFlowEngine.project(
            startingBalance: startingBalance,
            monthlyIncome: baseIncome,
            monthlyExpenses: baseExpenses,
            monthsAhead: 24
        )
    }

    private var annualIncome: Decimal {
        baseIncome * 12
    }

    private var taxBreakdown: TaxBreakdown {
        let sePortion = personalEntity?.selfEmploymentPortion ?? 0
        return IncomeTaxEngine.calculate(
            grossIncome: annualIncome,
            selfEmploymentIncome: annualIncome * Decimal(sePortion),
            filingStatus: personalEntity?.filingStatus ?? .single,
            stateRate: personalEntity?.stateTaxRate ?? 0
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headlineRow
                cashFlowSection
                netWorthSection
                if !liabilities.isEmpty {
                    debtPayoffSection
                }
                wealthSection
                goalsSection
                scenariosSection
                taxSection
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { addingGoal = true } label: {
                        Label("Add Goal", systemImage: "target")
                    }
                    Button { addingScenario = true } label: {
                        Label("Add Scenario", systemImage: "rectangle.stack")
                    }
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Planning")
        .sheet(isPresented: $addingGoal) {
            AddGoalSheet()
                .frame(minWidth: 520, minHeight: 380)
        }
        .sheet(isPresented: $addingScenario) {
            AddScenarioSheet(baseIncome: baseIncome, baseExpenses: baseExpenses, baseBalance: startingBalance)
                .frame(minWidth: 520, minHeight: 460)
        }
    }

    private var headlineRow: some View {
        HStack(spacing: 14) {
            HeadlineMetric(
                label: "Monthly Income",
                value: currency(baseIncome),
                detail: "\(jobs.filter { $0.status == .active }.count) job · \(apps.count) app\(apps.count == 1 ? "" : "s")"
            )
            HeadlineMetric(
                label: "Monthly Expenses",
                value: currency(baseExpenses),
                detail: personalEntity == nil ? "Set personal profile" : "Personal profile"
            )
            HeadlineMetric(
                label: "Net / month",
                value: currency(projection.monthlyNet),
                detail: projection.monthlyNet >= 0 ? "Positive" : "Burning",
                tint: projection.monthlyNet >= 0 ? .green : .red
            )
            HeadlineMetric(
                label: "Runway",
                value: runwayLabel,
                detail: runwayDetail
            )
        }
    }

    private var runwayLabel: String {
        if let months = projection.monthsToZero {
            return "\(months) mo"
        }
        if projection.monthlyNet >= 0 {
            return "∞"
        }
        return "—"
    }

    private var runwayDetail: String {
        if projection.monthsToZero != nil {
            return "Until balance = 0"
        }
        if projection.monthlyNet >= 0 {
            return "Cash-flow positive"
        }
        return "Starting balance zero"
    }

    private var cashFlowSection: some View {
        SectionShell(title: "Cash flow — 24 months out") {
            CashFlowChartView(projection: projection)
        }
    }

    private var netWorthSection: some View {
        SectionShell(title: "Net worth & balance sheet") {
            NetWorthSection(items: balanceSheetItems)
        }
    }

    private var liabilities: [BalanceSheetItem] {
        balanceSheetItems.filter { !$0.isAsset }
    }

    private var debtPayoffSection: some View {
        SectionShell(title: "Debt payoff planner") {
            DebtPayoffView(liabilities: liabilities)
        }
    }

    private var wealthSection: some View {
        SectionShell(title: "Wealth projection & financial independence") {
            WealthProjectionView(
                startingBalance: wealthStartingBalance,
                defaultMonthlyContribution: max(0, projection.monthlyNet)
            )
        }
    }

    private var goalsSection: some View {
        SectionShell(title: "Goals") {
            if goals.isEmpty {
                EmptyHint(text: "No goals yet. Add a savings target and we'll project the hit date.")
            } else {
                VStack(spacing: 10) {
                    ForEach(goals) { goal in
                        GoalRow(goal: goal, monthlySavings: projection.monthlyNet)
                            .contextMenu { deleteButton(goal) }
                    }
                }
            }
        }
    }

    private var scenariosSection: some View {
        SectionShell(title: "Scenarios") {
            if scenarios.isEmpty {
                EmptyHint(text: "No scenarios yet. \"What if I quit my job in 6 months?\" — model it.")
            } else {
                VStack(spacing: 12) {
                    ForEach(scenarios) { scenario in
                        ScenarioRow(
                            scenario: scenario,
                            jobs: jobs,
                            apps: apps,
                            personal: personalEntity,
                            baseIncome: baseIncome,
                            baseExpenses: baseExpenses,
                            baseBalance: startingBalance
                        )
                        .contextMenu { deleteButton(scenario) }
                    }
                }
            }
        }
    }

    private func deleteButton<T: PersistentModel>(_ entity: T) -> some View {
        Button(role: .destructive) {
            modelContext.delete(entity)
            try? modelContext.save()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var taxSection: some View {
        SectionShell(title: "Tax estimate") {
            VStack(alignment: .leading, spacing: 10) {
                TaxBreakdownCard(
                    breakdown: taxBreakdown,
                    filingStatus: personalEntity?.filingStatus ?? .single
                )
                if let due = taxBreakdown.nextDueDate {
                    Button {
                        NotificationService.scheduleTaxReminder(dueDate: due, quarterlyAmount: taxBreakdown.quarterlyPayment)
                        taxReminderSet = true
                    } label: {
                        Label(taxReminderSet ? "Reminder set" : "Remind me 3 days before",
                              systemImage: taxReminderSet ? "bell.fill" : "bell")
                    }
                    .buttonStyle(.bordered)
                    .disabled(taxReminderSet)
                }
            }
        }
    }
}

private struct HeadlineMetric: View {
    let label: String
    let value: String
    let detail: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().weight(.medium))
                .foregroundStyle(tint)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

struct SectionShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.85))
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}

struct EmptyHint: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}
