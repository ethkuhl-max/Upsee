import SwiftUI
import SwiftData

struct AppsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppEntity.updatedAt, order: .reverse) private var apps: [AppEntity]
    @Query private var timeEntries: [TimeEntry]
    @Query(sort: \DecisionEntity.createdAt, order: .reverse) private var decisionLog: [DecisionEntity]

    @State private var editor: EntityEditor?
    @State private var logSheet: LogTarget?
    @State private var statusFilter: AppStatus?
    @State private var verdictFilter: AppVerdict?
    @State private var sortMode: AppsSortMode = .verdict

    private var recommendations: [AppDecisionRecommendation] {
        apps.map { AppDecisionEngine.recommend(app: $0, timeEntries: timeEntries) }
    }

    private var portfolioRevenue: Decimal {
        apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue }
    }

    private var portfolioHours: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return timeEntries
            .filter { $0.entityKind == "app" && $0.startedAt >= cutoff }
            .reduce(0.0) { $0 + $1.hours }
    }

    private var verdictMix: [AppVerdict: Int] {
        Dictionary(grouping: recommendations, by: { $0.verdict }).mapValues { $0.count }
    }

    private var filteredRecommendations: [AppDecisionRecommendation] {
        var result = recommendations
        if let statusFilter {
            let nameSet = Set(apps.filter { $0.status == statusFilter }.map { $0.name })
            result = result.filter { nameSet.contains($0.appName) }
        }
        if let verdictFilter {
            result = result.filter { $0.verdict == verdictFilter }
        }
        switch sortMode {
        case .verdict:
            result.sort { AppsSortMode.verdictOrder($0.verdict) < AppsSortMode.verdictOrder($1.verdict) }
        case .revenue:
            result.sort { $0.monthlyRevenue > $1.monthlyRevenue }
        case .hours:
            result.sort { $0.hoursLogged > $1.hoursLogged }
        case .roi:
            result.sort { $0.revenuePerHour > $1.revenuePerHour }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                portfolioHeader
                filterBar
                appsList
            }
            .padding(24)
        }
        .navigationTitle("Apps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editor = .app(nil) } label: {
                    Label("Add app", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $editor) { editor in
            AddEntitySheet(editor: editor).frame(minWidth: 520, minHeight: 460)
        }
        .sheet(item: $logSheet) { target in
            LogDecisionSheet(target: target).frame(minWidth: 520, minHeight: 440)
        }
    }

    private var portfolioHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                portfolioStat("MRR", currency(portfolioRevenue), tint: portfolioRevenue > 0 ? .primary : .secondary)
                portfolioStat("Hours (30d)", String(format: "%.1fh", portfolioHours))
                portfolioStat("Portfolio $/hr", portfolioHourlyValue)
                portfolioStat("Apps", "\(apps.count)")
            }
            verdictMixRow
        }
    }

    private var portfolioHourlyValue: String {
        guard portfolioHours > 0 else { return "—" }
        let rev = NSDecimalNumber(decimal: portfolioRevenue).doubleValue
        return "$\(Int(rev / portfolioHours))/hr"
    }

    private var verdictMixRow: some View {
        HStack(spacing: 6) {
            ForEach(AppVerdict.allCases, id: \.self) { verdict in
                if let count = verdictMix[verdict], count > 0 {
                    Button {
                        verdictFilter = (verdictFilter == verdict) ? nil : verdict
                    } label: {
                        HStack(spacing: 4) {
                            Circle().fill(verdict.tint).frame(width: 6, height: 6)
                            Text("\(count) \(verdict.displayName)").font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(verdict.tint.opacity(verdictFilter == verdict ? 0.25 : 0.10))
                        )
                        .foregroundStyle(verdict.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }

    private func portfolioStat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Sort", selection: $sortMode) {
                ForEach(AppsSortMode.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            Picker("Status", selection: $statusFilter) {
                Text("All statuses").tag(AppStatus?.none)
                ForEach(AppStatus.allCases, id: \.self) {
                    Text($0.displayName).tag(AppStatus?.some($0))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)

            if statusFilter != nil || verdictFilter != nil {
                Button("Clear filters") {
                    statusFilter = nil
                    verdictFilter = nil
                }
                .buttonStyle(.borderless).controlSize(.small)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var appsList: some View {
        if apps.isEmpty {
            EmptyHint(text: "Add an app to start tracking revenue, hours, ship cadence, and decisions.")
        } else if filteredRecommendations.isEmpty {
            ContentUnavailableView {
                Label("No apps match", systemImage: "magnifyingglass")
            } description: {
                Text("Adjust the filters above.")
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredRecommendations) { rec in
                    if let app = apps.first(where: { $0.name == rec.appName }) {
                        NavigationLink {
                            AppDetailView(app: app)
                        } label: {
                            AppDecisionCard(rec: rec, onLog: {
                                logSheet = .app(name: rec.appName, recommendation: rec.verdict.displayName)
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

enum AppsSortMode: String, CaseIterable {
    case verdict, revenue, hours, roi

    var displayName: String {
        switch self {
        case .verdict: return "By verdict"
        case .revenue: return "By revenue"
        case .hours: return "By hours logged"
        case .roi: return "By $/hr"
        }
    }

    static func verdictOrder(_ v: AppVerdict) -> Int {
        switch v {
        case .doubleDown: return 0
        case .grow: return 1
        case .rescue: return 2
        case .hold: return 3
        case .kill: return 4
        }
    }
}
