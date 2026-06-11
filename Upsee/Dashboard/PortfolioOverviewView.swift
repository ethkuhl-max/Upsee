import SwiftUI
import SwiftData
import Charts

/// A one-screen rollup of everything: income mix, MRR, net worth, and the deal pipeline.
struct PortfolioOverviewView: View {
    @Query private var apps: [AppEntity]
    @Query private var jobs: [JobEntity]
    @Query private var deals: [DealEntity]
    @Query private var personal: [PersonalEntity]
    @Query private var balanceSheetItems: [BalanceSheetItem]

    private var jobIncome: Decimal { jobs.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.monthlyCompensation } }
    private var appIncome: Decimal { apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue } }
    private var otherIncome: Decimal { personal.first?.monthlyIncome ?? 0 }
    private var totalIncome: Decimal { jobIncome + appIncome + otherIncome }
    private var netWorth: NetWorthSummary { NetWorthEngine.summarize(balanceSheetItems) }
    private var activeDeals: Int { deals.filter { $0.status != .passed && $0.status != .dead }.count }

    private struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let value: Decimal
        let color: Color
    }

    private var incomeSlices: [Slice] {
        [
            Slice(label: "Jobs", value: jobIncome, color: .blue),
            Slice(label: "Apps", value: appIncome, color: .green),
            Slice(label: "Other", value: otherIncome, color: .gray),
        ].filter { dbl($0.value) > 0 }
    }

    private struct PipelineBar: Identifiable {
        let id = UUID()
        let status: DealStatus
        let count: Int
    }

    private var pipeline: [PipelineBar] {
        DealStatus.allCases.map { status in
            PipelineBar(status: status, count: deals.filter { $0.status == status }.count)
        }.filter { $0.count > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headline
                if !incomeSlices.isEmpty { incomeMixSection }
                if !pipeline.isEmpty { pipelineSection }
                netWorthSection
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .navigationTitle("Overview")
    }

    private var headline: some View {
        HStack(spacing: 14) {
            metric("Monthly income", currency(totalIncome), tint: .green)
            metric("App MRR", currency(appIncome))
            metric("Net worth", currency(netWorth.netWorth), tint: netWorth.netWorth >= 0 ? .primary : .red)
            metric("Active deals", "\(activeDeals)")
        }
    }

    private var incomeMixSection: some View {
        section("Income mix") {
            HStack(alignment: .center, spacing: 28) {
                Chart(incomeSlices) { slice in
                    SectorMark(
                        angle: .value("Amount", dbl(slice.value)),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(3)
                }
                .frame(width: 180, height: 180)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(incomeSlices) { slice in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(slice.color).frame(width: 12, height: 12)
                            Text(slice.label).font(.callout)
                            Spacer()
                            Text(currency(slice.value)).font(.callout.monospacedDigit())
                            Text(share(slice.value)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 320)
            }
        }
    }

    private var pipelineSection: some View {
        section("Deal pipeline") {
            Chart(pipeline) { bar in
                BarMark(
                    x: .value("Stage", bar.status.displayName),
                    y: .value("Deals", bar.count)
                )
                .foregroundStyle(bar.status.tint)
                .annotation(position: .top) {
                    Text("\(bar.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
        }
    }

    private var netWorthSection: some View {
        section("Balance sheet") {
            HStack(spacing: 14) {
                metric("Assets", currency(netWorth.totalAssets), tint: .green)
                metric("Liabilities", currency(netWorth.totalLiabilities), tint: .orange)
                metric("Net worth", currency(netWorth.netWorth), tint: netWorth.netWorth >= 0 ? .primary : .red)
                metric("Leverage", String(format: "%.0f%%", netWorth.leverageRatio * 100))
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }

    private func metric(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title2.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 14)
    }

    private func share(_ value: Decimal) -> String {
        let total = dbl(totalIncome)
        guard total > 0 else { return "" }
        return String(format: "%.0f%%", dbl(value) / total * 100)
    }

    private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}
