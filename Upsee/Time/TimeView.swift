import SwiftUI
import SwiftData

struct TimeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var apps: [AppEntity]
    @Query private var jobs: [JobEntity]
    @Query private var deals: [DealEntity]
    @Query(sort: \TimeEntry.startedAt, order: .reverse) private var entries: [TimeEntry]

    @State private var timer = ActiveTimer()
    @State private var tick = Date()
    @State private var addingManual = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var taggables: [TimeTaggable] {
        var list: [TimeTaggable] = []
        list.append(contentsOf: apps.map { TimeTaggable(kind: "app", label: $0.name) })
        list.append(contentsOf: jobs.map { TimeTaggable(kind: "job", label: $0.title) })
        list.append(contentsOf: deals.map { TimeTaggable(kind: "deal", label: $0.businessName) })
        list.append(TimeTaggable(kind: "personal", label: "Personal"))
        list.append(TimeTaggable(kind: "other", label: "Other"))
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StopwatchCard(timer: timer, tick: tick, taggables: taggables)
                TimeRollupView(entries: Array(entries), apps: Array(apps))
                recentSection
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addingManual = true } label: {
                    Label("Add Entry", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Time")
        .onReceive(ticker) { date in tick = date }
        .sheet(isPresented: $addingManual) {
            AddTimeEntrySheet(taggables: taggables)
                .frame(minWidth: 480, minHeight: 360)
        }
    }

    private var recentSection: some View {
        SectionShell(title: "Recent entries") {
            if entries.isEmpty {
                EmptyHint(text: "No entries logged yet. Start the stopwatch or add a manual entry.")
            } else {
                VStack(spacing: 8) {
                    ForEach(entries.prefix(30)) { entry in
                        TimeEntryRow(entry: entry, onDelete: {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        })
                    }
                }
            }
        }
    }
}

struct TimeTaggable: Identifiable, Hashable {
    let kind: String
    let label: String
    var id: String { "\(kind)/\(label)" }
}

private struct StopwatchCard: View {
    @Bindable var timer: ActiveTimer
    let tick: Date
    let taggables: [TimeTaggable]

    @Environment(\.modelContext) private var modelContext
    @State private var selectedTag: TimeTaggable?
    @State private var noteText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(timer.isRunning ? "Running" : "Stopwatch")
                    .font(.headline)
                    .foregroundStyle(timer.isRunning ? .green : .primary)
                Spacer()
                Text(timer.elapsedDisplay)
                    .font(.title.monospacedDigit().weight(.medium))
                    .foregroundStyle(timer.isRunning ? .primary : .secondary)
                    .id(tick)
            }

            if timer.isRunning {
                HStack {
                    Pill(text: timer.entityLabel ?? "—", tint: .green)
                    if !timer.note.isEmpty {
                        Text(timer.note).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                if timer.isRunning {
                    Button(role: .destructive) {
                        timer.cancel()
                    } label: {
                        Label("Discard", systemImage: "xmark.circle")
                    }
                    Spacer()
                    Button {
                        timer.stop(modelContext: modelContext)
                    } label: {
                        Label("Stop & log", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
                } else {
                    Picker("Tag", selection: $selectedTag) {
                        Text("Select…").tag(nil as TimeTaggable?)
                        ForEach(taggables) { t in
                            Text(t.label).tag(t as TimeTaggable?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    TextField("Note (optional)", text: $noteText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        guard let tag = selectedTag else { return }
                        timer.start(entityKind: tag.kind, entityLabel: tag.label, note: noteText)
                        noteText = ""
                    } label: {
                        Label("Start", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedTag == nil)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(timer.isRunning ? Color.green.opacity(0.06) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(timer.isRunning ? Color.green.opacity(0.35) : Color.secondary.opacity(0.12))
        )
    }
}

private struct TimeEntryRow: View {
    let entry: TimeEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Pill(text: entry.entityLabel, tint: tint(for: entry.entityKind))
                    Text(formatDuration(entry.minutes))
                        .font(.callout.monospacedDigit().weight(.medium))
                }
                if !entry.note.isEmpty {
                    Text(entry.note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(relative(entry.startedAt))
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private func tint(for kind: String) -> Color {
        switch kind {
        case "app": return .blue
        case "job": return .orange
        case "deal": return .purple
        case "personal": return .green
        default: return .secondary
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct AddTimeEntrySheet: View {
    let taggables: [TimeTaggable]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tag: TimeTaggable?
    @State private var minutesText = "30"
    @State private var note = ""
    @State private var startedAt = Date()

    private var canSave: Bool { tag != nil && (Int(minutesText) ?? 0) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Log Time Entry").font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tag").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Tag", selection: $tag) {
                            Text("Select…").tag(nil as TimeTaggable?)
                            ForEach(taggables) { t in
                                Text(t.label).tag(t as TimeTaggable?)
                            }
                        }
                        .pickerStyle(.menu).labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minutes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("30", text: $minutesText)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("When").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        DatePicker("When", selection: $startedAt)
                            .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("Optional", text: $note)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    guard let tag = tag, let minutes = Int(minutesText), minutes > 0 else { return }
                    let entry = TimeEntry(
                        startedAt: startedAt,
                        minutes: minutes,
                        note: note,
                        entityKind: tag.kind,
                        entityLabel: tag.label
                    )
                    modelContext.insert(entry)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
