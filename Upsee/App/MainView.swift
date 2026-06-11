import SwiftUI

struct MainView: View {
    @State private var section: UpseeSection? = .overview
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
                    sectionRawValue: (section ?? .overview).rawValue,
                    sectionLabel: (section ?? .overview).label
                ) {
                    detail
                }
                .background(UpseeBackdrop())
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
        switch section ?? .overview {
        case .overview: HomeView(open: { section = $0 })
        case .clients: ClientsView()
        case .dashboard: DashboardView()
        case .apps: AppsView()
        case .briefing: BriefingView()
        case .planning: PlanningView()
        case .health: HealthView()
        case .wealth: WealthView()
        case .decisions: DecisionsView()
        case .planner: PlannerView()
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
    case overview, clients, dashboard, apps, briefing, planning, health, wealth, decisions, planner, activity, transactions, bills, loans, imports, time
    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Home"
        case .clients: return "Clients"
        case .dashboard: return "Dashboard"
        case .apps: return "Apps"
        case .briefing: return "Briefing"
        case .planning: return "Planning"
        case .health: return "Health"
        case .wealth: return "Wealth"
        case .decisions: return "Decisions"
        case .planner: return "Planner"
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
        case .overview: return "house.fill"
        case .clients: return "person.2"
        case .dashboard: return "rectangle.3.group"
        case .apps: return "square.grid.2x2"
        case .briefing: return "sparkles.rectangle.stack"
        case .planning: return "chart.line.uptrend.xyaxis"
        case .health: return "heart.text.square"
        case .wealth: return "banknote"
        case .decisions: return "scale.3d"
        case .planner: return "person.2.badge.gearshape"
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
        case .wealth, .transactions, .loans, .planning, .clients, .decisions, .bills, .planner: return true
        default: return false
        }
    }

    /// Grouped sidebar layout. A nil title renders without a section header.
    static let sidebarGroups: [(title: String?, sections: [UpseeSection])] = [
        (nil, [.overview]),
        ("Portfolio", [.dashboard, .apps, .clients, .decisions, .time]),
        ("Money", [.wealth, .transactions, .bills, .loans, .planner, .planning]),
        ("Insights", [.briefing, .activity, .health]),
        ("Data", [.imports]),
    ]
}

struct Sidebar: View {
    @Binding var selection: UpseeSection?
    let onOpenLockSettings: () -> Void

    @Environment(LockManager.self) private var lockManager

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(Array(UpseeSection.sidebarGroups.enumerated()), id: \.offset) { _, group in
                    if let title = group.title {
                        Section(title) {
                            ForEach(group.sections) { section in
                                row(for: section)
                            }
                        }
                    } else {
                        ForEach(group.sections) { section in
                            row(for: section)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Upsee")

            LockControlsFooter(onOpenSettings: onOpenLockSettings)
        }
    }

    @ViewBuilder
    private func row(for section: UpseeSection) -> some View {
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
