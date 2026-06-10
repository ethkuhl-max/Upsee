import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppEntity.updatedAt, order: .reverse) private var apps: [AppEntity]
    @Query(sort: \JobEntity.updatedAt, order: .reverse) private var jobs: [JobEntity]
    @Query(sort: \DealEntity.updatedAt, order: .reverse) private var deals: [DealEntity]
    @Query private var personal: [PersonalEntity]

    @State private var editor: EntityEditor?
    @State private var selectedDeal: DealEntity?
    @State private var showingDealAnalyzer = false
    @State private var showingComparison = false

    @State private var searchText = ""
    @State private var typeFilter: DashboardTypeFilter = .all
    @State private var dealStatusFilter: DealStatus?
    @State private var sortOption: DashboardSort = .recent

    @State private var pendingRestore: Data?
    @State private var importMessage: String?

    private var analyzedDeals: [DealEntity] {
        deals.filter { $0.analysisData != nil }
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            || typeFilter != .all
            || dealStatusFilter != nil
    }

    private func matches(_ values: String...) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return values.contains { $0.lowercased().contains(q) }
    }

    private var filteredApps: [AppEntity] {
        guard typeFilter == .all || typeFilter == .apps else { return [] }
        let f = apps.filter { matches($0.name, $0.summary, $0.marketingNote) }
        switch sortOption {
        case .recent: return f
        case .name: return f.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case .value: return f.sorted { $0.monthlyRevenue > $1.monthlyRevenue }
        }
    }

    private var filteredJobs: [JobEntity] {
        guard typeFilter == .all || typeFilter == .jobs else { return [] }
        let f = jobs.filter { matches($0.title, $0.employer, $0.note) }
        switch sortOption {
        case .recent: return f
        case .name: return f.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .value: return f.sorted { $0.monthlyCompensation > $1.monthlyCompensation }
        }
    }

    private var filteredDeals: [DealEntity] {
        guard typeFilter == .all || typeFilter == .deals else { return [] }
        let f = deals.filter { deal in
            (dealStatusFilter == nil || deal.status == dealStatusFilter)
                && matches(deal.businessName, deal.industry.displayName, deal.lastVerdictHeadline, deal.note)
        }
        switch sortOption {
        case .recent: return f
        case .name: return f.sorted { $0.businessName.lowercased() < $1.businessName.lowercased() }
        case .value: return f.sorted { $0.askingPrice > $1.askingPrice }
        }
    }

    private var personalVisible: PersonalEntity? {
        guard typeFilter == .all || typeFilter == .personal else { return nil }
        guard let me = personal.first else { return nil }
        return matches("personal", me.note) ? me : nil
    }

    private var hasVisibleResults: Bool {
        personalVisible != nil || !filteredApps.isEmpty || !filteredJobs.isEmpty || !filteredDeals.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    EmptyDashboard(onAdd: { editor = $0 }, onAnalyzeDeal: { showingDealAnalyzer = true }, onLoadDemo: { loadDemoData() })
                } else {
                    populatedBody
                }
            }
            .toolbar { toolbar }
            .navigationTitle("Upsee")
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search portfolio")
            .sheet(item: $editor) { editor in
                AddEntitySheet(editor: editor)
                    .frame(minWidth: 520, minHeight: 460)
            }
            .sheet(item: $selectedDeal) { deal in
                SavedDealView(deal: deal, onClose: { selectedDeal = nil })
                    .frame(minWidth: 920, minHeight: 640)
            }
            .sheet(isPresented: $showingDealAnalyzer) {
                DealAnalysisFlowView(onClose: { showingDealAnalyzer = false })
                    .frame(minWidth: 920, minHeight: 640)
            }
            .sheet(isPresented: $showingComparison) {
                DealComparisonView(deals: analyzedDeals, onClose: { showingComparison = false })
                    .frame(minWidth: 760, minHeight: 560)
            }
            .confirmationDialog(
                "Replace all data with this backup?",
                isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                titleVisibility: .visible
            ) {
                Button("Replace everything", role: .destructive) {
                    if let data = pendingRestore { BackupService.restore(data, into: modelContext) }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("This erases the current portfolio, deals, planning, and balance sheet, then loads the backup.")
            }
            .alert("Import", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    private func importCSV() {
        guard let data = ExportService.openData(types: [.commaSeparatedText, .plainText]) else { return }
        let count = CSVImport.importApps(from: data, into: modelContext)
        importMessage = count > 0
            ? "Imported \(count) app\(count == 1 ? "" : "s")."
            : "No rows imported — the CSV needs a 'name' column."
    }

    private func loadDemoData() {
        DemoData.load(into: modelContext)
    }

    private func exportBackup() {
        guard let data = BackupService.export(modelContext) else { return }
        ExportService.save(data, suggestedName: "upsee-backup.json", type: .json)
    }

    private func importBackup() {
        if let data = ExportService.openData(types: [.json]) {
            pendingRestore = data
        }
    }

    private var isEmpty: Bool {
        apps.isEmpty && jobs.isEmpty && deals.isEmpty && personal.isEmpty
    }

    @ViewBuilder
    private var populatedBody: some View {
        if !hasVisibleResults {
            ContentUnavailableView {
                Label("No matches", systemImage: "magnifyingglass")
            } description: {
                Text("Nothing matches the current search and filters.")
            } actions: {
                Button("Clear filters") {
                    searchText = ""
                    typeFilter = .all
                    dealStatusFilter = nil
                }
            }
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 16)],
                    spacing: 16
                ) {
                    if let me = personalVisible {
                        PersonalEntityCard(entity: me)
                            .onTapGesture { editor = .personal(me) }
                            .contextMenu {
                                Button { editor = .personal(me) } label: { Label("Edit", systemImage: "pencil") }
                                Divider()
                                deleteButton(me)
                            }
                    }
                    ForEach(filteredJobs) { job in
                        JobEntityCard(entity: job)
                            .onTapGesture { editor = .job(job) }
                            .contextMenu {
                                Button { editor = .job(job) } label: { Label("Edit", systemImage: "pencil") }
                                Divider()
                                deleteButton(job)
                            }
                    }
                    ForEach(filteredApps) { app in
                        AppEntityCard(entity: app)
                            .onTapGesture { editor = .app(app) }
                            .contextMenu {
                                Button { editor = .app(app) } label: { Label("Edit", systemImage: "pencil") }
                                Divider()
                                deleteButton(app)
                            }
                    }
                    ForEach(filteredDeals) { deal in
                        DealEntityCard(entity: deal)
                            .onTapGesture { selectedDeal = deal }
                            .contextMenu { dealContextMenu(deal) }
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private func dealContextMenu(_ deal: DealEntity) -> some View {
        Button { selectedDeal = deal } label: { Label("Open", systemImage: "doc.text.magnifyingglass") }
        Menu("Move to") {
            ForEach(DealStatus.allCases, id: \.self) { status in
                Button {
                    deal.status = status
                    deal.updatedAt = Date()
                    try? modelContext.save()
                } label: {
                    if deal.status == status {
                        Label(status.displayName, systemImage: "checkmark")
                    } else {
                        Text(status.displayName)
                    }
                }
            }
        }
        Divider()
        deleteButton(deal)
    }

    private func deleteButton<T: PersistentModel>(_ entity: T) -> some View {
        Button(role: .destructive) {
            modelContext.delete(entity)
            try? modelContext.save()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu {
                Picker("Show", selection: $typeFilter) {
                    ForEach(DashboardTypeFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                Menu("Deal status") {
                    Button {
                        dealStatusFilter = nil
                    } label: {
                        if dealStatusFilter == nil { Label("Any", systemImage: "checkmark") } else { Text("Any") }
                    }
                    ForEach(DealStatus.allCases, id: \.self) { status in
                        Button {
                            dealStatusFilter = status
                        } label: {
                            if dealStatusFilter == status { Label(status.displayName, systemImage: "checkmark") } else { Text(status.displayName) }
                        }
                    }
                }
                Divider()
                Picker("Sort by", selection: $sortOption) {
                    ForEach(DashboardSort.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
            } label: {
                Label("Filter", systemImage: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
        }
        if analyzedDeals.count >= 2 {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingComparison = true
                } label: {
                    Label("Compare Deals", systemImage: "rectangle.split.3x1")
                }
            }
        }
        ToolbarItem(placement: .automatic) {
            Menu {
                Button { exportBackup() } label: { Label("Export Backup…", systemImage: "arrow.up.doc") }
                Button { importBackup() } label: { Label("Restore Backup…", systemImage: "arrow.down.doc") }
                Divider()
                Button { importCSV() } label: { Label("Import Apps (CSV)…", systemImage: "tablecells") }
                Button { loadDemoData() } label: { Label("Load Sample Data", systemImage: "sparkles") }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    editor = .app(nil)
                } label: {
                    Label("Add App", systemImage: "app.dashed")
                }
                Button {
                    editor = .job(nil)
                } label: {
                    Label("Add Job", systemImage: "briefcase")
                }
                Button {
                    showingDealAnalyzer = true
                } label: {
                    Label("Analyze a Deal", systemImage: "doc.text.magnifyingglass")
                }
                if personal.isEmpty {
                    Divider()
                    Button {
                        editor = .personal(nil)
                    } label: {
                        Label("Set Personal Profile", systemImage: "person.crop.circle")
                    }
                }
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
            }
        }
    }
}

enum DashboardTypeFilter: String, CaseIterable, Identifiable {
    case all, apps, jobs, deals, personal
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "Everything"
        case .apps: return "Apps"
        case .jobs: return "Jobs"
        case .deals: return "Deals"
        case .personal: return "Personal"
        }
    }
}

enum DashboardSort: String, CaseIterable, Identifiable {
    case recent, name, value
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recent: return "Most recent"
        case .name: return "Name (A–Z)"
        case .value: return "Value (high → low)"
        }
    }
}

private struct EmptyDashboard: View {
    let onAdd: (EntityEditor) -> Void
    let onAnalyzeDeal: () -> Void
    let onLoadDemo: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Welcome to Upsee")
                    .font(.title2.weight(.medium))
                Text("Your portfolio of apps, jobs, deals, and personal CFO — in one place. Add something to start.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            HStack(spacing: 12) {
                Button { onAdd(.app(nil)) } label: {
                    Label("Add an App", systemImage: "app.dashed")
                }
                Button { onAdd(.job(nil)) } label: {
                    Label("Add a Job", systemImage: "briefcase")
                }
                Button { onAnalyzeDeal() } label: {
                    Label("Analyze a Deal", systemImage: "doc.text.magnifyingglass")
                }
                Button { onAdd(.personal(nil)) } label: {
                    Label("Personal Profile", systemImage: "person.crop.circle")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button { onLoadDemo() } label: {
                Label("Load sample data to explore", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
