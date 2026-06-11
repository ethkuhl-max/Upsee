import SwiftUI
import SwiftData

/// One-page command center. Every number that matters, on one screen,
/// each tile a click-through to its section. Replaces the old Overview.
struct HomeView: View {
    /// Navigation hook back into MainView's sidebar selection.
    let open: (UpseeSection) -> Void

    @Environment(LockManager.self) private var lockManager

    @Query private var apps: [AppEntity]
    @Query private var jobs: [JobEntity]
    @Query private var deals: [DealEntity]
    @Query private var personal: [PersonalEntity]
    @Query private var balanceSheet: [BalanceSheetItem]
    @Query private var bills: [Bill]
    @Query private var loans: [Loan]
    @Query private var budgets: [Budget]
    @Query private var transactions: [Transaction]
    @Query private var timeEntries: [TimeEntry]
    @Query private var commitments: [WeeklyCommitment]
    @Query(sort: \DecisionEntity.createdAt, order: .reverse) private var decisions: [DecisionEntity]
    @Query(sort: \NetWorthSnapshot.date, order: .reverse) private var snapshots: [NetWorthSnapshot]
    @Query(sort: \BriefingEntity.createdAt, order: .reverse) private var briefings: [BriefingEntity]

    // MARK: - Derived

    private var me: PersonalEntity? { personal.first }

    private var netWorthSummary: NetWorthSummary { NetWorthEngine.summarize(balanceSheet) }

    private var mrr: Decimal { apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue } }

    private var monthlyIncome: Decimal {
        let jobIncome = jobs.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.monthlyCompensation }
        return jobIncome + mrr + (me?.monthlyIncome ?? 0)
    }

    private var fi: FISummary {
        FIEngine.summarize(
            annualExpenses: (me?.monthlyExpenses ?? 0) * 12,
            netWorth: netWorthSummary.netWorth,
            annualSavings: max(0, monthlyIncome - (me?.monthlyExpenses ?? 0)) * 12
        )
    }

    private var hoursThisWeek: Double {
        let weekStart = WeekStart.of(Date())
        return timeEntries.filter { $0.startedAt >= weekStart }.reduce(0.0) { $0 + $1.hours }
    }

    private var billSummary: BillCalendarSummary { BillScheduleEngine.summarize(bills) }

    private var subscriptions: [DetectedSubscription] { SubscriptionEngine.detect(transactions: transactions) }

    private var budgetSummary: BudgetSummary { BudgetEngine.summarize(budgets: budgets, transactions: transactions) }

    private var loansBalance: Decimal { loans.reduce(Decimal(0)) { $0 + $1.currentBalance } }

    private var staleDecisions: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return decisions.filter { $0.outcome.isEmpty && $0.createdAt <= cutoff }.count
    }

    private var liveDeals: Int {
        deals.filter { $0.status != .dead && $0.status != .passed }.count
    }

    private var activeCommitments: [WeeklyCommitment] {
        commitments.filter { $0.isCurrentWeek && $0.status == .inProgress }
    }

    private var netWorthDeltaDetail: String {
        guard let latest = snapshots.first else { return "No snapshots yet" }
        let delta = netWorthSummary.netWorth - latest.netWorth
        return "\(delta >= 0 ? "+" : "")\(masked(delta)) since \(relative(latest.date))"
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                heroRow
                attentionStrip
                moneyGrid
                portfolioGrid
            }
            .padding(22)
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let latest = briefings.first {
                AttentionChip(
                    icon: "sparkles.rectangle.stack",
                    text: "Briefing from \(relative(latest.createdAt))",
                    tint: .pink
                ) { open(.briefing) }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var heroRow: some View {
        HStack(spacing: 14) {
            HeroTile(
                icon: "chart.pie.fill",
                title: "Net Worth",
                value: masked(netWorthSummary.netWorth),
                detail: netWorthDeltaDetail,
                tint: .blue,
                progress: nil
            ) { open(.wealth) }

            HeroTile(
                icon: "flag.checkered",
                title: "Financial Independence",
                value: String(format: "%.1f%%", fi.progress * 100),
                detail: fi.yearsToFI.map { String(format: "~%.0f yrs to FI at current pace", $0) } ?? "Set expenses to project",
                tint: .green,
                progress: fi.progress
            ) { open(.wealth) }

            HeroTile(
                icon: "app.badge.fill",
                title: "Portfolio MRR",
                value: masked(mrr),
                detail: "\(apps.count) apps · \(masked(monthlyIncome))/mo total income",
                tint: .purple
            ) { open(.apps) }

            HeroTile(
                icon: "clock.fill",
                title: "This Week",
                value: String(format: "%.1fh", hoursThisWeek),
                detail: activeCommitments.isEmpty
                    ? "No weekly focus set"
                    : "\(activeCommitments.count) commitment\(activeCommitments.count == 1 ? "" : "s") in flight",
                tint: .orange
            ) { open(.time) }
        }
    }

    @ViewBuilder
    private var attentionStrip: some View {
        let overdue = billSummary.overdue.count
        let dueWeek = billSummary.dueThisWeek.count
        let overBudget = budgetSummary.overCategories.count
        let zombies = SubscriptionEngine.zombieCandidates(subscriptions).count

        if overdue + dueWeek + overBudget + zombies + staleDecisions > 0 {
            FlowLayout(spacing: 8) {
                if overdue > 0 {
                    AttentionChip(icon: "exclamationmark.octagon.fill", text: "\(overdue) overdue bill\(overdue == 1 ? "" : "s")", tint: .red) { open(.bills) }
                }
                if dueWeek > 0 {
                    AttentionChip(icon: "calendar.badge.clock", text: "\(dueWeek) due this week", tint: .orange) { open(.bills) }
                }
                if overBudget > 0 {
                    AttentionChip(icon: "gauge.with.needle.fill", text: "\(overBudget) over budget", tint: .red) { open(.transactions) }
                }
                if zombies > 0 {
                    AttentionChip(icon: "repeat.circle", text: "\(zombies) zombie sub\(zombies == 1 ? "" : "s")", tint: .purple) { open(.transactions) }
                }
                if staleDecisions > 0 {
                    AttentionChip(icon: "questionmark.diamond.fill", text: "\(staleDecisions) decision\(staleDecisions == 1 ? "" : "s") need retro", tint: .indigo) { open(.decisions) }
                }
            }
        }
    }

    private var moneyGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            gridLabel("Money")
            LazyVGrid(columns: tileColumns, spacing: 12) {
                GlassTile(
                    icon: "list.bullet.rectangle.portrait",
                    title: "Transactions",
                    value: "\(transactionsLast30.count)",
                    detail: "\(masked(outflowLast30)) out · 30d",
                    tint: .teal
                ) { open(.transactions) }

                GlassTile(
                    icon: "repeat.circle.fill",
                    title: "Subscriptions",
                    value: masked(SubscriptionEngine.monthlyBurn(subscriptions)) + "/mo",
                    detail: "\(subscriptions.count) detected",
                    tint: .purple
                ) { open(.transactions) }

                GlassTile(
                    icon: "calendar.badge.clock",
                    title: "Bills",
                    value: masked(billSummary.monthlyCommitted) + "/mo",
                    detail: "\(billSummary.upcomingMonth.count) due in 30d",
                    tint: .orange,
                    badgeCount: billSummary.overdue.count
                ) { open(.bills) }

                GlassTile(
                    icon: "creditcard.fill",
                    title: "Loans",
                    value: masked(loansBalance),
                    detail: "\(loans.count) loan\(loans.count == 1 ? "" : "s")",
                    tint: .red
                ) { open(.loans) }

                GlassTile(
                    icon: "person.2.badge.gearshape.fill",
                    title: "Planner",
                    value: nextTaxDueLabel,
                    detail: "Goals · IPS · Roth · Estate",
                    tint: .green
                ) { open(.planner) }

                GlassTile(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Planning",
                    value: runwayLabel,
                    detail: "Cash flow & scenarios",
                    tint: .blue
                ) { open(.planning) }
            }
        }
    }

    private var portfolioGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            gridLabel("Portfolio & Operations")
            LazyVGrid(columns: tileColumns, spacing: 12) {
                GlassTile(
                    icon: "square.grid.2x2.fill",
                    title: "Apps",
                    value: "\(apps.count)",
                    detail: masked(mrr) + "/mo gross",
                    tint: .purple
                ) { open(.apps) }

                GlassTile(
                    icon: "doc.text.magnifyingglass",
                    title: "Deals",
                    value: "\(liveDeals)",
                    detail: "in pipeline",
                    tint: .teal
                ) { open(.dashboard) }

                GlassTile(
                    icon: "scale.3d",
                    title: "Decisions",
                    value: "\(decisions.count)",
                    detail: matchRateLabel,
                    tint: .indigo,
                    badgeCount: staleDecisions
                ) { open(.decisions) }

                GlassTile(
                    icon: "waveform.path.ecg",
                    title: "Activity",
                    value: "\(activityCountLast7)",
                    detail: "events · 7d",
                    tint: .cyan
                ) { open(.activity) }

                GlassTile(
                    icon: "heart.text.square.fill",
                    title: "Health",
                    value: hoursThisWeek > 50 ? "Heavy" : "OK",
                    detail: String(format: "%.0fh logged this week", hoursThisWeek),
                    tint: hoursThisWeek > 50 ? .orange : .pink
                ) { open(.health) }

                GlassTile(
                    icon: "tray.and.arrow.down.fill",
                    title: "Imports",
                    value: "ASC · Bank",
                    detail: "Drop CSVs to sync data",
                    tint: .blue
                ) { open(.imports) }
            }
        }
    }

    // MARK: - Helpers

    private var tileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170, maximum: 260), spacing: 12)]
    }

    private func gridLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }

    private var transactionsLast30: [Transaction] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return [] }
        return transactions.filter { $0.date >= cutoff }
    }

    private var outflowLast30: Decimal {
        transactionsLast30.filter { $0.isOutflow }.reduce(Decimal(0)) { $0 - $1.amount }
    }

    private var runwayLabel: String {
        guard let p = me else { return "—" }
        let months = p.runwayMonths
        if months.isInfinite { return "∞ runway" }
        return String(format: "%.1fmo runway", months)
    }

    private var nextTaxDueLabel: String {
        guard let due = TaxEstimator.nextQuarterlyDueDate(from: Date()) else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        return "Tax in \(days)d"
    }

    private var matchRateLabel: String {
        guard !decisions.isEmpty else { return "no calls logged" }
        let matched = decisions.filter { $0.matchedRecommendation }.count
        return "\(Int(Double(matched) / Double(decisions.count) * 100))% match rate"
    }

    private var activityCountLast7: Int {
        // Lightweight proxy: decisions + snapshots + transactions in the last 7 days.
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return decisions.filter { $0.createdAt >= cutoff }.count
            + snapshots.filter { $0.date >= cutoff }.count
            + transactions.filter { $0.createdAt >= cutoff }.count
    }

    private func masked(_ d: Decimal) -> String {
        lockManager.isPrivacyMode ? "••••" : currency(d)
    }
}
