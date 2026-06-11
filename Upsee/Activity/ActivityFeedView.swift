import SwiftUI
import SwiftData

struct ActivityFeedView: View {
    @Query(sort: \AppEntity.updatedAt, order: .reverse) private var apps: [AppEntity]
    @Query private var releases: [ReleaseEntry]
    @Query private var roadmap: [RoadmapItem]
    @Query(sort: \DecisionEntity.createdAt, order: .reverse) private var decisions: [DecisionEntity]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journal: [JournalEntry]
    @Query(sort: \NetWorthSnapshot.date, order: .reverse) private var snapshots: [NetWorthSnapshot]
    @Query(sort: \TaxPayment.paidAt, order: .reverse) private var taxPayments: [TaxPayment]
    @Query(sort: \BriefingEntity.createdAt, order: .reverse) private var briefings: [BriefingEntity]
    @Query(sort: \WeeklyCommitment.weekStart, order: .reverse) private var commitments: [WeeklyCommitment]
    @Query private var deals: [DealEntity]
    @Query(sort: \ImportLogEntry.importedAt, order: .reverse) private var imports: [ImportLogEntry]

    @State private var activeFilters: Set<ActivityEventKind> = []
    @State private var searchText: String = ""

    private var events: [ActivityEvent] {
        let sources = ActivityEventBuilder.Sources(
            apps: apps,
            releases: releases,
            roadmap: roadmap,
            decisions: decisions,
            journal: journal,
            snapshots: snapshots,
            taxPayments: taxPayments,
            briefings: briefings,
            commitments: commitments,
            deals: deals,
            imports: imports
        )
        return ActivityEventBuilder.build(sources)
    }

    private var filteredEvents: [ActivityEvent] {
        var result = events
        if !activeFilters.isEmpty {
            result = result.filter { activeFilters.contains($0.kind) }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(trimmed) ||
                ($0.detail?.lowercased().contains(trimmed) ?? false) ||
                ($0.entityLabel?.lowercased().contains(trimmed) ?? false)
            }
        }
        return result
    }

    private var grouped: [(date: Date, events: [ActivityEvent])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filteredEvents) { event -> Date in
            cal.startOfDay(for: event.date)
        }
        return dict
            .map { (date: $0.key, events: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                filterChips
                if filteredEvents.isEmpty {
                    EmptyHint(text: "Nothing yet — release an app, log a decision, snap your net worth, or write a journal entry to populate the feed.")
                } else {
                    ForEach(grouped, id: \.date) { day in
                        dayGroup(date: day.date, events: day.events)
                    }
                }
            }
            .padding(24)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search activity")
        .navigationTitle("Activity")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                stat("Events", "\(events.count)")
                stat("Last 7 days", "\(events.filter { isWithin(days: 7, $0.date) }.count)")
                stat("Reviews needed", "\(events.filter { $0.kind == .reviewNeeded }.count)",
                     tint: events.contains { $0.kind == .reviewNeeded } ? .orange : .secondary)
                Spacer()
            }
            Text("Everything that happened across your portfolio, in one stream.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var filterChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(ActivityEventKind.allCases, id: \.self) { kind in
                let active = activeFilters.contains(kind)
                Button {
                    if active { activeFilters.remove(kind) } else { activeFilters.insert(kind) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: kind.systemImage).font(.caption2)
                        Text(kind.displayName).font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(kind.tint.opacity(active ? 0.25 : 0.10)))
                    .foregroundStyle(kind.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayGroup(date: Date, events: [ActivityEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(dayLabel(date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
            }
            ForEach(events) { event in
                EventRow(event: event)
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        return date.formatted(.dateTime.weekday(.wide).month().day()).uppercased()
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func isWithin(days: Int, _ date: Date) -> Bool {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return false }
        return date >= cutoff
    }
}

private struct EventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(event.kind.tint.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: event.kind.systemImage)
                    .font(.caption)
                    .foregroundStyle(event.kind.tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.title).font(.callout.weight(.medium))
                    if let label = event.entityLabel {
                        Pill(text: label, tint: event.kind.tint)
                    }
                    Spacer()
                    Text(event.date.formatted(.dateTime.hour().minute()))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                if let detail = event.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
    }
}
