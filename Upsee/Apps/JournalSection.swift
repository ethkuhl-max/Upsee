import SwiftUI
import SwiftData

struct JournalSection: View {
    let entityKind: String
    let entityLabel: String

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]

    @State private var addingEntry = false
    @State private var filterKind: JournalEntryKind?

    private var entries: [JournalEntry] {
        let scoped = allEntries.filter { $0.entityKind == entityKind && $0.entityLabel == entityLabel }
        let filtered = filterKind.map { kind in scoped.filter { $0.kind == kind } } ?? scoped
        return filtered.sorted { (a, b) in
            if a.pinned != b.pinned { return a.pinned }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            kindFilter
            if entries.isEmpty {
                EmptyHint(text: "No journal entries yet. Capture observations, blockers, wins, questions — anything that's worth remembering later.")
            } else {
                ForEach(entries) { entry in
                    JournalRow(entry: entry, onDelete: {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }, onTogglePin: {
                        entry.pinned.toggle()
                        try? modelContext.save()
                    })
                }
            }
        }
        .sheet(isPresented: $addingEntry) {
            AddJournalEntrySheet(entityKind: entityKind, entityLabel: entityLabel).frame(minWidth: 520, minHeight: 380)
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                addingEntry = true
            } label: {
                Label("Add entry", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var kindFilter: some View {
        FlowLayout(spacing: 6) {
            ForEach(JournalEntryKind.allCases, id: \.self) { kind in
                let active = filterKind == kind
                Button {
                    filterKind = active ? nil : kind
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: kind.systemImage).font(.caption2)
                        Text(kind.displayName).font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(kind.tint.opacity(active ? 0.25 : 0.10)))
                    .foregroundStyle(kind.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct JournalRow: View {
    let entry: JournalEntry
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: entry.kind.systemImage)
                    .foregroundStyle(entry.kind.tint)
                Text(entry.kind.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(entry.kind.tint)
                if entry.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.yellow)
                }
                Spacer()
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                Button(action: onTogglePin) {
                    Image(systemName: entry.pinned ? "pin.slash" : "pin").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            Text(entry.body).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(entry.kind.tint.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(entry.kind.tint.opacity(0.15)))
    }
}

struct AddJournalEntrySheet: View {
    let entityKind: String
    let entityLabel: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var kind: JournalEntryKind = .observation
    @State private var bodyText: String = ""
    @State private var pinned: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Journal entry — \(entityLabel)").font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("KIND").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Kind", selection: $kind) {
                    ForEach(JournalEntryKind.allCases, id: \.self) { k in
                        Text(k.displayName).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("BODY").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.3)))
            }

            Toggle("Pin to top", isOn: $pinned).toggleStyle(.switch)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let entry = JournalEntry(
                        entityKind: entityKind,
                        entityLabel: entityLabel,
                        body: bodyText,
                        kind: kind,
                        pinned: pinned
                    )
                    modelContext.insert(entry)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
    }
}
