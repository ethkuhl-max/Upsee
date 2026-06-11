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
        case .clients: ClientsView()
        case .dashboard: DashboardView()
        case .apps: AppsView()
        case .briefing: BriefingView()
        case .planning: PlanningView()
        case .health: HealthView()
        case .wealth: WealthView()
        case .decisions: DecisionsView()
        case .activity: ActivityFeedView()
        case .transactions: TransactionsView()
        case .loans: LoansView()
        case .imports: ASCImportView()
        case .time: TimeView()
        }
    }
}

enum UpseeSection: String, Hashable, CaseIterable, Identifiable {
    case overview, clients, dashboard, apps, briefing, planning, health, wealth, decisions, activity, transactions, loans, imports, time
    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .clients: return "Clients"
        case .dashboard: return "Dashboard"
        case .apps: return "Apps"
        case .briefing: return "Briefing"
        case .planning: return "Planning"
        case .health: return "Health"
        case .wealth: return "Wealth"
        case .decisions: return "Decisions"
        case .activity: return "Activity"
        case .transactions: return "Transactions"
        case .loans: return "Loans"
        case .imports: return "Imports"
        case .time: return "Time"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "chart.pie"
        case .clients: return "person.2"
        case .dashboard: return "rectangle.3.group"
        case .apps: return "square.grid.2x2"
        case .briefing: return "sparkles.rectangle.stack"
        case .planning: return "chart.line.uptrend.xyaxis"
        case .health: return "heart.text.square"
        case .wealth: return "banknote"
        case .decisions: return "scale.3d"
        case .activity: return "waveform.path.ecg"
        case .transactions: return "list.bullet.rectangle.portrait"
        case .loans: return "creditcard"
        case .imports: return "tray.and.arrow.down"
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
