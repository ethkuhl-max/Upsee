import SwiftUI
import SwiftData

struct DecisionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppEntity.updatedAt, order: .reverse) private var apps: [AppEntity]
    @Query(sort: \JobEntity.updatedAt, order: .reverse) private var jobs: [JobEntity]
    @Query(sort: \DealEntity.updatedAt, order: .reverse) private var deals: [DealEntity]
    @Query private var personal: [PersonalEntity]
    @Query private var timeEntries: [TimeEntry]
    @Query(sort: \DecisionEntity.createdAt, order: .reverse) private var decisionLog: [DecisionEntity]

    @State private var logSheet: LogTarget?

    private var personalEntity: PersonalEntity? { personal.first }

    private var appsRevenue: Decimal {
        apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue }
    }

    private var appRecommendations: [AppDecisionRecommendation] {
        apps
            .filter { $0.status != .sunset }
            .map { AppDecisionEngine.recommend(app: $0, timeEntries: timeEntries) }
            .sorted { Self.verdictOrder($0.verdict) < Self.verdictOrder($1.verdict) }
    }

    private var jobRecommendations: [JobDecisionRecommendation] {
        jobs
            .filter { $0.status != .ended }
            .map { JobDecisionEngine.recommend(job: $0, personal: personalEntity, appsRevenue: appsRevenue) }
    }

    private var dealRecommendations: [DealDecisionRecommendation] {
        deals
            .filter { $0.status != .dead && $0.status != .passed }
            .map { DealDecisionEngine.recommend(deal: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                appsSection
                jobsSection
                dealsSection
                decisionLogSection
            }
            .padding(24)
        }
        .navigationTitle("Decisions")
        .sheet(item: $logSheet) { target in
            LogDecisionSheet(target: target)
                .frame(minWidth: 520, minHeight: 440)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What does the math say?")
                .font(.title3.weight(.semibold))
            Text("Mechanical recommendations based on revenue, hours logged, and analysis. The numbers don't account for joy or strategic optionality — log a counter-decision when they're wrong, and the log will show your hit rate over time.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    @ViewBuilder
    private var appsSection: some View {
        SectionShell(title: "Apps") {
            if appRecommendations.isEmpty {
                EmptyHint(text: "No active apps to evaluate. Add one in the Dashboard.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(appRecommendations) { rec in
                        AppDecisionCard(rec: rec, onLog: {
                            logSheet = .app(name: rec.appName, recommendation: rec.verdict.displayName)
                        })
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var jobsSection: some View {
        SectionShell(title: "Jobs") {
            if jobRecommendations.isEmpty {
                EmptyHint(text: "No active or pending jobs to evaluate.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(jobRecommendations) { rec in
                        JobDecisionCard(rec: rec, onLog: {
                            logSheet = .job(label: "\(rec.jobTitle) — \(rec.employer)", recommendation: rec.verdict.displayName)
                        })
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dealsSection: some View {
        SectionShell(title: "Deals") {
            if dealRecommendations.isEmpty {
                EmptyHint(text: "No live deals in the pipeline.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(dealRecommendations) { rec in
                        DealDecisionCard(rec: rec, onLog: {
                            logSheet = .deal(name: rec.businessName, recommendation: rec.verdict.displayName)
                        })
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var decisionLogSection: some View {
        SectionShell(title: "Decision log") {
            if decisionLog.isEmpty {
                EmptyHint(text: "When you log a decision (matching or overriding the recommendation), it'll appear here. Update the outcome later to grade your judgment.")
            } else {
                DecisionLogList(entries: decisionLog)
            }
        }
    }

    private static func verdictOrder(_ v: AppVerdict) -> Int {
        switch v {
        case .doubleDown: return 0
        case .grow: return 1
        case .rescue: return 2
        case .hold: return 3
        case .kill: return 4
        }
    }
}

enum LogTarget: Identifiable {
    case app(name: String, recommendation: String)
    case job(label: String, recommendation: String)
    case deal(name: String, recommendation: String)

    var id: String {
        switch self {
        case .app(let name, _): return "app-\(name)"
        case .job(let label, _): return "job-\(label)"
        case .deal(let name, _): return "deal-\(name)"
        }
    }

    var kind: DecisionKind {
        switch self {
        case .app: return .app
        case .job: return .job
        case .deal: return .deal
        }
    }

    var label: String {
        switch self {
        case .app(let name, _): return name
        case .job(let label, _): return label
        case .deal(let name, _): return name
        }
    }

    var recommendation: String {
        switch self {
        case .app(_, let r), .job(_, let r), .deal(_, let r): return r
        }
    }
}

extension AppVerdict {
    var tint: Color {
        switch self {
        case .doubleDown: return .green
        case .grow: return .blue
        case .hold: return .secondary
        case .kill: return .red
        case .rescue: return .orange
        }
    }
}

extension JobVerdict {
    var tint: Color {
        switch self {
        case .takeIt: return .green
        case .negotiate: return .blue
        case .decline: return .red
        case .continueSearch: return .orange
        }
    }
}

extension DealVerdict {
    var tint: Color {
        switch self {
        case .proceed: return .green
        case .proceedWithDD: return .blue
        case .walk: return .red
        case .watching: return .secondary
        }
    }
}
