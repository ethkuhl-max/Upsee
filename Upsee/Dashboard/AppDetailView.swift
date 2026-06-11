import SwiftUI
import SwiftData

struct AppDetailView: View {
    @Bindable var app: AppEntity
    @Environment(\.modelContext) private var modelContext

    @Query private var timeEntries: [TimeEntry]

    @State private var addingRoadmap = false
    @State private var addingRelease = false
    @State private var addingGoal = false
    @State private var editingMeta = false
    @State private var repoHealth: RepoHealthReport?
    @State private var refreshingRepo = false
    @State private var logSheet: LogTarget?

    private var decisionRec: AppDecisionRecommendation {
        AppDecisionEngine.recommend(app: app, timeEntries: timeEntries)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                decisionSection
                metricsRow
                weeklySection
                costsSectionView
                if app.repoPath != nil {
                    repoSection
                }
                goalsSection
                roadmapSection
                releasesSection
                journalSectionView
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .sheet(item: $logSheet) { target in
            LogDecisionSheet(target: target).frame(minWidth: 520, minHeight: 440)
        }
        .task(id: app.repoPath) { await loadRepoHealth() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button { addingRoadmap = true } label: { Label("Roadmap Item", systemImage: "list.bullet.rectangle") }
                    Button { addingRelease = true } label: { Label("Release", systemImage: "shippingbox") }
                    Button { addingGoal = true } label: { Label("Goal", systemImage: "target") }
                } label: { Label("Add", systemImage: "plus.circle.fill") }
                Button { editingMeta = true } label: { Label("Edit", systemImage: "pencil") }
            }
        }
        .navigationTitle(app.name)
        .sheet(isPresented: $addingRoadmap) {
            AddRoadmapSheet(app: app).frame(minWidth: 560, minHeight: 480)
        }
        .sheet(isPresented: $addingRelease) {
            AddReleaseSheet(app: app).frame(minWidth: 560, minHeight: 480)
        }
        .sheet(isPresented: $addingGoal) {
            AddAppGoalSheet(app: app).frame(minWidth: 520, minHeight: 420)
        }
        .sheet(isPresented: $editingMeta) {
            EditAppSheet(app: app).frame(minWidth: 520, minHeight: 460)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(app.name).font(.title.weight(.semibold))
                Pill(text: app.status.displayName, tint: app.status.tint)
                Spacer()
            }
            if !app.summary.isEmpty {
                Text(app.summary).font(.callout).foregroundStyle(.secondary)
            }
            if let repo = app.repoPath, !repo.isEmpty {
                Label(repo, systemImage: "folder")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var decisionSection: some View {
        SectionShell(title: "Recommendation") {
            AppDecisionCard(rec: decisionRec, onLog: {
                logSheet = .app(name: app.name, recommendation: decisionRec.verdict.displayName)
            })
        }
    }

    private var weeklySection: some View {
        SectionShell(title: "Weekly focus") {
            WeeklyCommitmentSection(app: app, timeEntries: timeEntries)
        }
    }

    private var journalSectionView: some View {
        SectionShell(title: "Journal") {
            JournalSection(entityKind: "app", entityLabel: app.name)
        }
    }

    private var costsSectionView: some View {
        SectionShell(title: "Costs & net profit") {
            CostsSection(app: app)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 14) {
            metricCard("MRR", currency(app.monthlyRevenue))
            metricCard("Users", "\(app.activeUsers)")
            metricCard("In flight", "\(app.inFlightCount)")
            metricCard("Next ship", app.nextTargetVersion ?? "—")
            metricCard(
                "Last shipped",
                app.lastShippedAt.map(relative) ?? "—"
            )
        }
    }

    private func metricCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }

    private var repoSection: some View {
        SectionShell(title: "Repo health") {
            if refreshingRepo && repoHealth == nil {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Inspecting repo…").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassPanel(cornerRadius: 14)
            } else if let report = repoHealth {
                VStack(alignment: .leading, spacing: 8) {
                    RepoHealthCard(report: report)
                    HStack {
                        Spacer()
                        Button {
                            Task { await loadRepoHealth(force: true) }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .disabled(refreshingRepo)
                    }
                }
            } else {
                EmptyHint(text: "Set a repo path on this app to surface git health here.")
            }
        }
    }

    @MainActor
    private func loadRepoHealth(force: Bool = false) async {
        guard let path = app.repoPath, !path.isEmpty else {
            repoHealth = nil
            return
        }
        if !force && repoHealth?.path == (path as NSString).expandingTildeInPath {
            return
        }
        refreshingRepo = true
        defer { refreshingRepo = false }
        repoHealth = await GitInspector.inspect(repoPath: path)
    }

    private var goalsSection: some View {
        SectionShell(title: "Goals") {
            if app.goals.isEmpty {
                EmptyHint(text: "No goals set. \"100 CFIs by Q4\" or \"$500 MRR by year end.\"")
            } else {
                VStack(spacing: 10) {
                    ForEach(app.goals.sorted { ($0.targetDate ?? .distantFuture) < ($1.targetDate ?? .distantFuture) }) { goal in
                        AppGoalRow(goal: goal)
                    }
                }
            }
        }
    }

    private var roadmapSection: some View {
        SectionShell(title: "Roadmap") {
            if app.roadmap.isEmpty {
                EmptyHint(text: "Nothing on the roadmap. Capture an idea or plan a feature.")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(roadmapGroups, id: \.0) { (status, items) in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Pill(text: status.displayName, tint: status.tint)
                                Text("\(items.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 6) {
                                ForEach(items) { item in
                                    RoadmapItemRow(item: item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var releasesSection: some View {
        SectionShell(title: "Releases") {
            if app.releases.isEmpty {
                EmptyHint(text: "No release history yet. Log a release to start the version timeline.")
            } else {
                VStack(spacing: 10) {
                    ForEach(app.releases.sorted { $0.releasedAt > $1.releasedAt }) { release in
                        ReleaseRow(release: release)
                    }
                }
            }
        }
    }

    private var roadmapGroups: [(RoadmapStatus, [RoadmapItem])] {
        let grouped = Dictionary(grouping: app.roadmap) { $0.status }
        return RoadmapStatus.allCases
            .compactMap { status in
                guard let items = grouped[status], !items.isEmpty else { return nil }
                let sorted = items.sorted {
                    if $0.priority.sortRankPriority != $1.priority.sortRankPriority {
                        return $0.priority.sortRankPriority < $1.priority.sortRankPriority
                    }
                    return $0.updatedAt > $1.updatedAt
                }
                return (status, sorted)
            }
    }
}

private extension RoadmapPriority {
    var sortRankPriority: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}
