import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ASCImportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AppEntity.updatedAt, order: .reverse) private var apps: [AppEntity]
    @Query(sort: \ImportLogEntry.importedAt, order: .reverse) private var logEntries: [ImportLogEntry]

    @State private var stagedResult: ASCImportResult?
    @State private var stagedFileName: String = ""
    @State private var errorMessage: String?
    /// Title → AppEntity name overrides for fuzzy mismatches.
    @State private var titleOverrides: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                dropZone
                if let result = stagedResult {
                    previewSection(result)
                }
                logSection
            }
            .padding(24)
        }
        .navigationTitle("App Store Connect Import")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Import sales without an API key")
                .font(.title3.weight(.semibold))
            Text("Download a Sales and Trends report from App Store Connect (Reports → Sales and Trends → Download). Drop the .txt file below. Upsee parses it and updates each matching app's revenue + downloads. Unmatched apps stay untouched.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 36))
                .foregroundStyle(Color.blue)
            Text("Drop ASC report here").font(.callout.weight(.medium))
            Button("Choose file…") { pickFile() }
                .buttonStyle(.bordered)
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red).padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.06)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }

    private func previewSection(_ result: ASCImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                previewStat("Rows", "\(result.totalRows)")
                previewStat("Units", "\(result.totalUnits)")
                previewStat("Total proceeds", currency(result.totalProceeds), tint: .green)
                if let earliest = result.earliestDate, let latest = result.latestDate {
                    previewStat("Range", "\(earliest.formatted(.dateTime.month().day())) – \(latest.formatted(.dateTime.month().day()))")
                }
                Spacer()
            }
            Text("Match each ASC title to an app — Upsee picks the closest name automatically; override if wrong.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(result.revenueByTitle.keys.sorted()), id: \.self) { title in
                matchRow(title: title, result: result)
            }
            HStack {
                Button("Cancel") {
                    stagedResult = nil
                    titleOverrides.removeAll()
                }
                Spacer()
                Button("Apply revenue updates") { applyImport(result) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private func matchRow(title: String, result: ASCImportResult) -> some View {
        let revenue = result.revenueByTitle[title] ?? 0
        let units = result.unitsByTitle[title] ?? 0
        let suggested = bestMatch(for: title)
        let selectedName = titleOverrides[title] ?? suggested
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text("\(units) units · \(currency(revenue))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Picker("Map to", selection: Binding(
                get: { selectedName },
                set: { titleOverrides[title] = $0 }
            )) {
                Text("— ignore —").tag(Optional<String>.none)
                ForEach(apps, id: \.name) { app in
                    Text(app.name).tag(Optional<String>.some(app.name))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 220)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import history").font(.callout.weight(.semibold))
            if logEntries.isEmpty {
                EmptyHint(text: "No imports yet. Drop a Sales and Trends file above to start.")
            } else {
                ForEach(logEntries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.source.systemImage).foregroundStyle(entry.source.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.fileName).font(.callout.weight(.medium))
                            Text(entry.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.importedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption.monospaced()).foregroundStyle(.tertiary)
                        Button(role: .destructive) {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.05)))
                }
            }
        }
    }

    private func previewStat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
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
            let result = try ASCSalesParser.parse(text)
            stagedResult = result
            stagedFileName = url.lastPathComponent
            errorMessage = nil
            titleOverrides = Dictionary(uniqueKeysWithValues: result.revenueByTitle.keys.map { ($0, bestMatch(for: $0) ?? "") })
        } catch {
            errorMessage = error.localizedDescription
            stagedResult = nil
        }
    }

    private func bestMatch(for title: String) -> String? {
        let lower = title.lowercased()
        if let exact = apps.first(where: { $0.name.lowercased() == lower }) { return exact.name }
        return apps.first { lower.contains($0.name.lowercased()) || $0.name.lowercased().contains(lower) }?.name
    }

    private func applyImport(_ result: ASCImportResult) {
        var changedNames: [String] = []
        var totalApplied: Decimal = 0
        var totalUnits = 0
        for (title, revenue) in result.revenueByTitle {
            guard let mapped = titleOverrides[title], !mapped.isEmpty,
                  let app = apps.first(where: { $0.name == mapped }) else { continue }
            app.monthlyRevenue = revenue
            if let units = result.unitsByTitle[title] {
                app.activeUsers = units
                totalUnits += units
            }
            app.updatedAt = Date()
            changedNames.append(mapped)
            totalApplied += revenue
        }
        let summary = "Updated \(changedNames.count) app\(changedNames.count == 1 ? "" : "s") — \(currency(totalApplied)) proceeds, \(totalUnits) units."
        let log = ImportLogEntry(
            source: .appStoreConnect,
            fileName: stagedFileName,
            summary: summary,
            changedEntityLabels: changedNames,
            totalAmount: totalApplied,
            unitsCount: totalUnits
        )
        modelContext.insert(log)
        try? modelContext.save()
        stagedResult = nil
        titleOverrides.removeAll()
    }
}
