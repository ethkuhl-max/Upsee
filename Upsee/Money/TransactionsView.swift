import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var rules: [CategoryRule]

    @State private var importStaged: BankImportResult?
    @State private var importFileName: String = ""
    @State private var importAccountName: String = ""
    @State private var importError: String?
    @State private var categoryFilter: TxCategory?
    @State private var searchText: String = ""

    enum TopTab: String, CaseIterable { case all, subscriptions, byCategory, importing
        var displayName: String {
            switch self {
            case .all: return "All"
            case .subscriptions: return "Subscriptions"
            case .byCategory: return "By Category"
            case .importing: return "Import"
            }
        }
    }
    @State private var tab: TopTab = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                tabBar
                switch tab {
                case .all: allList
                case .subscriptions: SubscriptionsView(transactions: transactions)
                case .byCategory: categoryBreakdown
                case .importing: importTab
                }
            }
            .padding(24)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search transactions")
        .navigationTitle("Transactions")
        .onAppear { ensureSeedRules() }
    }

    private var header: some View {
        let last30 = transactionsLast(days: 30)
        let inflow = last30.filter { $0.isInflow }.reduce(Decimal(0)) { $0 + $1.amount }
        let outflow = last30.filter { $0.isOutflow }.reduce(Decimal(0)) { $0 - $1.amount }
        let net = inflow - outflow
        return HStack(spacing: 14) {
            stat("Tx (30d)", "\(last30.count)")
            stat("Inflow", currency(inflow), tint: .green)
            stat("Outflow", currency(outflow), tint: .orange)
            stat("Net", currency(net), tint: net >= 0 ? .primary : .red)
            stat("Uncat", "\(transactions.filter { $0.category == .uncategorized }.count)",
                 tint: transactions.contains { $0.category == .uncategorized } ? .orange : .secondary)
            Spacer()
        }
    }

    private var tabBar: some View {
        Picker("Tab", selection: $tab) {
            ForEach(TopTab.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var allList: some View {
        VStack(alignment: .leading, spacing: 10) {
            categoryChips
            if filteredAll.isEmpty {
                EmptyHint(text: "No transactions match. Import a CSV from your bank to start.")
            } else {
                ForEach(filteredAll) { tx in
                    TransactionRow(transaction: tx, onDelete: {
                        modelContext.delete(tx)
                        try? modelContext.save()
                    }, onRecategorize: { newCat in
                        tx.category = newCat
                        try? modelContext.save()
                    })
                }
            }
        }
    }

    private var categoryChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(TxCategory.allCases, id: \.self) { cat in
                let active = categoryFilter == cat
                Button {
                    categoryFilter = active ? nil : cat
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: cat.systemImage).font(.caption2)
                        Text(cat.displayName).font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(cat.tint.opacity(active ? 0.25 : 0.10)))
                    .foregroundStyle(cat.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredAll: [Transaction] {
        var result = transactions
        if let cat = categoryFilter {
            result = result.filter { $0.category == cat }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.merchant.lowercased().contains(q) ||
                $0.rawDescription.lowercased().contains(q) ||
                $0.accountName.lowercased().contains(q)
            }
        }
        return result
    }

    private var categoryBreakdown: some View {
        let dict = Dictionary(grouping: transactionsLast(days: 30)) { $0.category }
        let totals: [(TxCategory, Decimal)] = TxCategory.allCases.compactMap { cat in
            guard let txs = dict[cat] else { return nil }
            let sum = txs.filter { $0.isOutflow }.reduce(Decimal(0)) { $0 - $1.amount }
            guard sum > 0 else { return nil }
            return (cat, sum)
        }.sorted { $0.1 > $1.1 }
        let grandTotal = totals.reduce(Decimal(0)) { $0 + $1.1 }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Last 30 days outflow by category").font(.callout.weight(.semibold))
            if totals.isEmpty {
                EmptyHint(text: "No outflows yet in the last 30 days.")
            } else {
                ForEach(totals, id: \.0) { (cat, amount) in
                    CategoryBar(category: cat, amount: amount, total: grandTotal)
                }
            }
        }
    }

    @ViewBuilder
    private var importTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import bank or credit transactions").font(.callout.weight(.semibold))
            Text("Download a CSV from your bank's site (most banks support 1-12 month exports), then drop it below. Upsee detects the column format, auto-categorizes via rules, and stages a preview before applying.")
                .font(.caption).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("ACCOUNT NAME").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Chase Checking / Amex Plat / etc", text: $importAccountName)
                    .textFieldStyle(.roundedBorder)
            }

            dropZone

            if let result = importStaged {
                stagedPreview(result)
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down").font(.system(size: 32)).foregroundStyle(Color.blue)
            Text("Drop CSV here").font(.callout.weight(.medium))
            Button("Choose file…") { pickFile() }.buttonStyle(.bordered)
            if let importError {
                Text(importError).font(.caption).foregroundStyle(.red).padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.blue.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers); return true
        }
    }

    private func stagedPreview(_ result: BankImportResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                stat("Format", result.detectedFormat)
                stat("Tx", "\(result.transactions.count)")
                stat("Inflow", currency(result.totalInflow), tint: .green)
                stat("Outflow", currency(result.totalOutflow), tint: .orange)
                Spacer()
            }
            if let earliest = result.earliestDate, let latest = result.latestDate {
                Text("Range: \(earliest.formatted(.dateTime.month().day())) – \(latest.formatted(.dateTime.month().day()))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel") { importStaged = nil }
                Spacer()
                Button("Apply") { applyStaged(result) }
                    .buttonStyle(.borderedProminent)
                    .disabled(importAccountName.isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }

    private func transactionsLast(days: Int) -> [Transaction] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return transactions }
        return transactions.filter { $0.date >= cutoff }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async { loadFile(at: url) }
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .tabSeparatedText, .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(at: url)
        }
    }

    private func loadFile(at url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            importStaged = try BankCSVParser.parse(text)
            importFileName = url.lastPathComponent
            importError = nil
        } catch {
            importError = error.localizedDescription
            importStaged = nil
        }
    }

    private func applyStaged(_ result: BankImportResult) {
        let batch = UUID().uuidString
        for parsed in result.transactions {
            let cat = autoCategory(merchant: parsed.merchant, description: parsed.rawDescription) ?? .uncategorized
            let tx = Transaction(
                date: parsed.date,
                amount: parsed.amount,
                merchant: parsed.merchant,
                rawDescription: parsed.rawDescription,
                accountName: importAccountName,
                category: cat,
                source: .bankCSV,
                importBatchID: batch
            )
            modelContext.insert(tx)
        }
        let log = ImportLogEntry(
            source: .bankCSV,
            fileName: importFileName,
            summary: "\(result.transactions.count) tx · \(currency(result.totalInflow)) in / \(currency(result.totalOutflow)) out · \(result.detectedFormat)",
            changedEntityLabels: [importAccountName],
            totalAmount: result.totalInflow - result.totalOutflow,
            unitsCount: result.transactions.count
        )
        modelContext.insert(log)
        try? modelContext.save()
        importStaged = nil
        importFileName = ""
    }

    private func autoCategory(merchant: String, description: String) -> TxCategory? {
        let blob = "\(merchant) \(description)".lowercased()
        let sorted = rules.sorted { $0.priority < $1.priority }
        for rule in sorted {
            if rule.matches(blob) { return rule.category }
        }
        return nil
    }

    private func ensureSeedRules() {
        guard rules.isEmpty else { return }
        for (pattern, category) in DefaultCategoryRules.seeds {
            modelContext.insert(CategoryRule(pattern: pattern, category: category))
        }
        try? modelContext.save()
    }
}

private struct TransactionRow: View {
    let transaction: Transaction
    let onDelete: () -> Void
    let onRecategorize: (TxCategory) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(transaction.category.tint.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: transaction.category.systemImage)
                    .font(.caption)
                    .foregroundStyle(transaction.category.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant).font(.callout.weight(.medium))
                HStack(spacing: 6) {
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2.monospaced())
                    Text("·").foregroundStyle(.tertiary)
                    Text(transaction.accountName).font(.caption2).foregroundStyle(.secondary)
                }
                .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(currency(transaction.amount))
                .font(.callout.monospacedDigit())
                .foregroundStyle(transaction.isInflow ? Color.green : Color.primary)
            Menu {
                ForEach(TxCategory.allCases, id: \.self) { cat in
                    Button {
                        onRecategorize(cat)
                    } label: {
                        Label(cat.displayName, systemImage: cat.systemImage)
                    }
                }
                Divider()
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }
}

private struct CategoryBar: View {
    let category: TxCategory
    let amount: Decimal
    let total: Decimal

    private var fraction: Double {
        let t = NSDecimalNumber(decimal: total).doubleValue
        guard t > 0 else { return 0 }
        return NSDecimalNumber(decimal: amount).doubleValue / t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: category.systemImage).foregroundStyle(category.tint)
                Text(category.displayName).font(.callout.weight(.medium))
                Spacer()
                Text(currency(amount)).font(.callout.monospacedDigit())
                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                    Rectangle().fill(category.tint.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }
}
