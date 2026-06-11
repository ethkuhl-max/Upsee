import SwiftUI

struct MainView: View {
    @State private var section: UpseeSection? = .dashboard
    @State private var showingLockSettings = false
    @Environment(LockManager.self) private var lockManager

    /// Drives auto-lock checks. Fires every 30s while the window is open.
    private let activityTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $section, onOpenLockSettings: { showingLockSettings = true })
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            NavigationStack {
                SectionLockGate(
                    sectionRawValue: (section ?? .dashboard).rawValue,
                    sectionLabel: (section ?? .dashboard).label
                ) {
                    detail
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task { NotificationService.requestAuthorization() }
        .onAppear { lockManager.recordActivity() }
        .onReceive(activityTimer) { _ in
            lockManager.evaluateAutoLock()
        }
        .sheet(isPresented: $showingLockSettings) {
            LockSettingsSheet().environment(lockManager)
        }
        // Any user interaction resets the inactivity clock.
        .simultaneousGesture(TapGesture().onEnded { lockManager.recordActivity() })
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
        case .bills: BillsView()
        case .loans: LoansView()
        case .imports: ASCImportView()
        case .time: TimeView()
        }
    }
}

enum UpseeSection: String, Hashable, CaseIterable, Identifiable {
    case overview, clients, dashboard, apps, briefing, planning, health, wealth, decisions, activity, transactions, bills, loans, imports, time
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
        case .bills: return "Bills"
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
        case .bills: return "calendar.badge.clock"
        case .loans: return "creditcard"
        case .imports: return "tray.and.arrow.down"
        case .time: return "clock.arrow.circlepath"
        }
    }

    /// Sections that hold sensitive financial data — surfaced as defaults in lock settings.
    var isSensitive: Bool {
        switch self {
        case .wealth, .transactions, .loans, .planning, .clients, .decisions, .bills: return true
        default: return false
        }
    }
}

struct Sidebar: View {
    @Binding var selection: UpseeSection?
    let onOpenLockSettings: () -> Void

    @Environment(LockManager.self) private var lockManager

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(UpseeSection.allCases) { section in
                    HStack(spacing: 6) {
                        Label(section.label, systemImage: section.systemImage)
                        if lockManager.isSectionLocked(section.rawValue) {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tag(section)
                    .contextMenu {
                        if section.isSensitive {
                            Button {
                                lockManager.toggleSectionLock(section.rawValue)
                            } label: {
                                Label(
                                    lockManager.isSectionLocked(section.rawValue) ? "Stop locking section" : "Always lock section",
                                    systemImage: "lock"
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Upsee")

            LockControlsFooter(onOpenSettings: onOpenLockSettings)
        }
    }
}

private struct LockControlsFooter: View {
    let onOpenSettings: () -> Void
    @Environment(LockManager.self) private var lockManager

    var body: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(spacing: 6) {
                Button {
                    lockManager.togglePrivacyMode()
                } label: {
                    Image(systemName: lockManager.isPrivacyMode ? "eye.slash.fill" : "eye")
                        .frame(width: 14)
                }
                .buttonStyle(.borderless)
                .help(lockManager.isPrivacyMode ? "Show amounts" : "Hide amounts (privacy mode)")
                .foregroundStyle(lockManager.isPrivacyMode ? Color.blue : .secondary)

                Button {
                    lockManager.lock()
                } label: {
                    Image(systemName: "lock.fill").frame(width: 14)
                }
                .buttonStyle(.borderless)
                .help("Lock now")
                .foregroundStyle(.secondary)

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape").frame(width: 14)
                }
                .buttonStyle(.borderless)
                .help("Lock & privacy settings")
                .foregroundStyle(.secondary)

                Spacer()

                if lockManager.isPrivacyMode {
                    Text("PRIVACY").font(.caption2.weight(.bold)).foregroundStyle(Color.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
