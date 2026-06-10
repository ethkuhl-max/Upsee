import SwiftUI

struct MainView: View {
    @State private var section: UpseeSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $section)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            NavigationStack {
                detail
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task { NotificationService.requestAuthorization() }
    }

    @ViewBuilder
    private var detail: some View {
        switch section ?? .dashboard {
        case .overview: PortfolioOverviewView()
        case .dashboard: DashboardView()
        case .briefing: BriefingView()
        case .planning: PlanningView()
        case .health: HealthView()
        case .wealth: WealthView()
        case .decisions: DecisionsView()
        case .time: TimeView()
        }
    }
}

enum UpseeSection: String, Hashable, CaseIterable, Identifiable {
    case overview, dashboard, briefing, planning, health, wealth, decisions, time
    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .dashboard: return "Dashboard"
        case .briefing: return "Briefing"
        case .planning: return "Planning"
        case .health: return "Health"
        case .wealth: return "Wealth"
        case .decisions: return "Decisions"
        case .time: return "Time"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "chart.pie"
        case .dashboard: return "rectangle.3.group"
        case .briefing: return "sparkles.rectangle.stack"
        case .planning: return "chart.line.uptrend.xyaxis"
        case .health: return "heart.text.square"
        case .wealth: return "banknote"
        case .decisions: return "scale.3d"
        case .time: return "clock.arrow.circlepath"
        }
    }
}

struct Sidebar: View {
    @Binding var selection: UpseeSection?

    var body: some View {
        List(selection: $selection) {
            ForEach(UpseeSection.allCases) { section in
                Label(section.label, systemImage: section.systemImage)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Upsee")
    }
}
