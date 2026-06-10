import SwiftUI
import SwiftData

struct BriefingView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BriefingEntity.createdAt, order: .reverse) private var briefings: [BriefingEntity]
    @Query private var apps: [AppEntity]
    @Query private var jobs: [JobEntity]
    @Query private var deals: [DealEntity]
    @Query private var personal: [PersonalEntity]
    @Query(sort: \TimeEntry.startedAt, order: .reverse) private var timeEntries: [TimeEntry]

    @State private var generator = BriefingGenerator()
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showingContext = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if briefings.isEmpty {
                    emptyState
                } else if let latest = briefings.first {
                    BriefingDetailView(briefing: latest, showingContext: $showingContext)
                    if briefings.count > 1 {
                        historySection
                    }
                }
                if let errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        Text(errorMessage).font(.callout).foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
                }
            }
            .padding(24)
        }
        .navigationTitle("Briefing")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await generate() }
                } label: {
                    Label(isGenerating ? "Generating…" : "New Briefing", systemImage: "sparkles")
                }
                .disabled(isGenerating || hasNoData)
            }
        }
    }

    private var hasNoData: Bool {
        apps.isEmpty && jobs.isEmpty && deals.isEmpty && personal.isEmpty
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("No briefing yet")
                .font(.title3.weight(.medium))
            Text(hasNoData
                ? "Add some entities on the dashboard first — apps, jobs, a personal profile."
                : "Generate the first briefing in the Underight voice across your whole portfolio.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            if !hasNoData {
                Button {
                    Task { await generate() }
                } label: {
                    Label(isGenerating ? "Generating…" : "Generate Briefing", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isGenerating)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Earlier briefings")
                .font(.title3.weight(.semibold))
            ForEach(briefings.dropFirst()) { briefing in
                BriefingHistoryRow(briefing: briefing, onDelete: { delete(briefing) })
            }
        }
    }

    @MainActor
    private func generate() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            let result = try await generator.generate(
                apps: Array(apps),
                jobs: Array(jobs),
                deals: Array(deals),
                personal: personal.first,
                timeEntries: Array(timeEntries)
            )
            let entity = BriefingEntity(
                overview: result.output.overview,
                driftAlerts: result.output.driftAlerts.joined(separator: "\n"),
                focusRecommendations: result.output.focusRecommendations.joined(separator: "\n"),
                surprise: result.output.surprise,
                contextSummary: result.context
            )
            modelContext.insert(entity)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ briefing: BriefingEntity) {
        modelContext.delete(briefing)
        try? modelContext.save()
    }
}

private struct BriefingDetailView: View {
    let briefing: BriefingEntity
    @Binding var showingContext: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(briefing.createdAt.formatted(date: .complete, time: .shortened))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingContext.toggle()
                } label: {
                    Label(showingContext ? "Hide context" : "Show context",
                          systemImage: "doc.text.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Text(briefing.overview)
                .font(.system(.title3, design: .serif))
                .lineSpacing(4)

            if !briefing.driftLines.isEmpty {
                section("Drifting", systemImage: "arrow.right.circle", tint: .orange) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(briefing.driftLines, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").foregroundStyle(.orange)
                                Text(line).font(.callout)
                            }
                        }
                    }
                }
            }

            if !briefing.focusLines.isEmpty {
                section("This week", systemImage: "target", tint: Color.accentColor) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(briefing.focusLines, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("→").foregroundStyle(Color.accentColor)
                                Text(line).font(.callout)
                            }
                        }
                    }
                }
            }

            if let surprise = briefing.surprise, !surprise.isEmpty {
                section("Worth noticing", systemImage: "sparkle", tint: .purple) {
                    Text(surprise).font(.callout.italic())
                }
            }

            if showingContext {
                section("Context sent to model", systemImage: "doc.plaintext", tint: .secondary) {
                    Text(briefing.contextSummary)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.secondary.opacity(0.12)))
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content()
        }
    }
}

private struct BriefingHistoryRow: View {
    let briefing: BriefingEntity
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(briefing.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            Text(briefing.overview)
                .font(.callout)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
    }
}
