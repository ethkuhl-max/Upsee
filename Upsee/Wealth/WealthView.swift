import SwiftUI
import SwiftData

struct WealthView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BalanceSheetItem.updatedAt, order: .reverse) private var balanceSheetItems: [BalanceSheetItem]
    @Query(sort: \NetWorthSnapshot.date, order: .reverse) private var snapshots: [NetWorthSnapshot]
    @Query(sort: \TaxPayment.paidAt, order: .reverse) private var taxPayments: [TaxPayment]
    @Query(sort: \RetirementAccount.updatedAt, order: .reverse) private var retirementAccounts: [RetirementAccount]
    @Query private var personal: [PersonalEntity]
    @Query private var apps: [AppEntity]
    @Query private var jobs: [JobEntity]
    @Query private var deals: [DealEntity]

    @State private var addingSnapshot = false
    @State private var addingTaxPayment = false
    @State private var addingRetirement = false
    @State private var monteCarloYears = 20
    @State private var monteCarloReturn: Double = 0.07
    @State private var monteCarloVolatility: Double = 0.15
    @State private var monteCarloTarget: String = ""

    private var personalEntity: PersonalEntity? { personal.first }

    private var allocation: AssetAllocationSummary {
        AssetAllocationEngine.summarize(balanceSheetItems)
    }

    private var summary: NetWorthSummary {
        NetWorthEngine.summarize(balanceSheetItems)
    }

    private var liquidAssets: Decimal {
        balanceSheetItems
            .filter { $0.category == .cash || $0.category == .investments }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var annualContribution: Decimal {
        guard let p = personalEntity else { return 0 }
        let net = p.monthlyIncome - p.monthlyExpenses
        return max(0, net) * 12
    }

    private var taxTracker: TaxTrackerData {
        TaxTrackerData(payments: taxPayments, personal: personalEntity, jobs: jobs, apps: apps)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                netWorthHeader
                fiSectionView
                allocationSection
                netWorthTrendSection
                monteCarloSection
                retirementSection
                taxSection
                adversarialSection
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { addingSnapshot = true } label: { Label("Snapshot today", systemImage: "camera.aperture") }
                    Button { addingTaxPayment = true } label: { Label("Log Tax Payment", systemImage: "dollarsign.circle") }
                    Button { addingRetirement = true } label: { Label("Add Retirement Account", systemImage: "building.columns") }
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Wealth")
        .sheet(isPresented: $addingSnapshot) {
            AddSnapshotSheet(items: balanceSheetItems).frame(minWidth: 460, minHeight: 320)
        }
        .sheet(isPresented: $addingTaxPayment) {
            AddTaxPaymentSheet().frame(minWidth: 480, minHeight: 420)
        }
        .sheet(isPresented: $addingRetirement) {
            AddRetirementAccountSheet().frame(minWidth: 520, minHeight: 460)
        }
    }

    private var netWorthHeader: some View {
        HStack(spacing: 14) {
            HeadlineMetric(
                label: "Net Worth",
                value: currencyMasked(summary.netWorth),
                detail: deltaDetail,
                tint: summary.netWorth >= 0 ? .primary : .red
            )
            HeadlineMetric(
                label: "Assets",
                value: currencyMasked(summary.totalAssets),
                detail: "\(allocation.slices.count) categor\(allocation.slices.count == 1 ? "y" : "ies")"
            )
            HeadlineMetric(
                label: "Liabilities",
                value: currencyMasked(summary.totalLiabilities),
                detail: String(format: "%.0f%% leverage", summary.leverageRatio * 100)
            )
            HeadlineMetric(
                label: "Liquid",
                value: currencyMasked(liquidAssets),
                detail: liquidDetail
            )
        }
    }

    private var deltaDetail: String {
        guard snapshots.count >= 1, let latest = snapshots.first else { return "No snapshots yet" }
        let delta = summary.netWorth - latest.netWorth
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(currencyMasked(delta)) since \(relative(latest.date))"
    }

    private var liquidDetail: String {
        guard let p = personalEntity, p.monthlyExpenses > 0 else { return "—" }
        let monthsCovered = NSDecimalNumber(decimal: liquidAssets).doubleValue
            / NSDecimalNumber(decimal: p.monthlyExpenses).doubleValue
        return String(format: "%.1fmo of expenses", monthsCovered)
    }

    private var fiSectionView: some View {
        SectionShell(title: "Financial independence") {
            FISection(
                annualExpenses: (personalEntity?.monthlyExpenses ?? 0) * 12,
                netWorth: summary.netWorth,
                annualSavings: annualContribution
            )
        }
    }

    private var allocationSection: some View {
        SectionShell(title: "Asset allocation") {
            AssetAllocationCard(summary: allocation)
        }
    }

    private var netWorthTrendSection: some View {
        SectionShell(title: "Net worth trend") {
            NetWorthTrendCard(snapshots: Array(snapshots.reversed()), currentSummary: summary)
        }
    }

    private var monteCarloSection: some View {
        SectionShell(title: "Wealth projection — \(monteCarloYears) years out") {
            MonteCarloProjectionCard(
                startingBalance: summary.netWorth,
                annualContribution: annualContribution,
                years: $monteCarloYears,
                expectedReturn: $monteCarloReturn,
                volatility: $monteCarloVolatility,
                target: $monteCarloTarget
            )
        }
    }

    private var retirementSection: some View {
        SectionShell(title: "Retirement accounts") {
            RetirementAccountsSection(accounts: retirementAccounts, onAdd: { addingRetirement = true })
        }
    }

    private var taxSection: some View {
        SectionShell(title: "Estimated tax tracker") {
            TaxPaymentTracker(data: taxTracker, onAdd: { addingTaxPayment = true })
        }
    }

    private var adversarialSection: some View {
        SectionShell(title: "Adversarial scenarios") {
            AdversarialScenariosCard(
                apps: Array(apps),
                jobs: Array(jobs),
                deals: Array(deals),
                personal: personalEntity,
                retirement: Array(retirementAccounts),
                netWorth: summary.netWorth,
                liquidAssets: liquidAssets,
                concentrationFlags: allocation.concentrationFlags
            )
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
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16)
    }
}
