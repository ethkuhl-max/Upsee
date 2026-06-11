import SwiftUI
import SwiftData

struct EstatePlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EstateDocument.createdAt) private var documents: [EstateDocument]
    @State private var editing: EstateDocument?

    private var checklist: [EstateDocument] {
        // Ensure one row per standard kind. Missing ones present as not-present rows.
        EstateDocKind.standardChecklist.map { kind in
            documents.first(where: { $0.kind == kind }) ?? EstateDocument(kind: kind, present: false)
        }
    }

    private var coreCompleted: Int {
        checklist.filter { $0.kind.isCore && $0.present }.count
    }

    private var coreTotal: Int {
        EstateDocKind.standardChecklist.filter { $0.isCore }.count
    }

    private var staleCount: Int {
        checklist.filter { $0.isStale }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            intro
            statsRow
            if staleCount > 0 { staleBanner }
            checklistSection
        }
        .sheet(item: $editing) { doc in
            EditEstateDocSheet(document: doc).frame(minWidth: 460, minHeight: 360)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estate planning checklist").font(.title3.weight(.semibold))
            Text("The point of a planner-grade estate review is completeness — what you have, where it lives, when it was last reviewed. Beneficiaries go stale fast.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            stat("Core completed", "\(coreCompleted) / \(coreTotal)",
                 tint: coreCompleted == coreTotal ? .green : .orange)
            stat("Stale (5y+)", "\(staleCount)", tint: staleCount > 0 ? .red : .secondary)
            stat("Documents tracked", "\(EstateDocKind.standardChecklist.count)")
            Spacer()
        }
    }

    private var staleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.red)
            Text("\(staleCount) document\(staleCount == 1 ? " is" : "s are") 5+ years old — beneficiaries and witnesses often change in that span")
                .font(.callout.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.18)))
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CHECKLIST").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(EstateDocKind.standardChecklist, id: \.self) { kind in
                let doc = documents.first(where: { $0.kind == kind })
                ChecklistRow(
                    kind: kind,
                    document: doc,
                    onToggle: { togglePresence(kind) },
                    onEdit: { editing = ensure(kind) }
                )
            }
        }
    }

    private func ensure(_ kind: EstateDocKind) -> EstateDocument {
        if let existing = documents.first(where: { $0.kind == kind }) { return existing }
        let new = EstateDocument(kind: kind, present: false)
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    private func togglePresence(_ kind: EstateDocKind) {
        let doc = ensure(kind)
        doc.present.toggle()
        if doc.present && doc.lastReviewedAt == nil {
            doc.lastReviewedAt = Date()
        }
        doc.updatedAt = Date()
        try? modelContext.save()
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(tint)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }
}

private struct ChecklistRow: View {
    let kind: EstateDocKind
    let document: EstateDocument?
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: document?.present == true ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(document?.present == true ? Color.green : Color.secondary)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            Image(systemName: kind.systemImage).foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(kind.displayName).font(.callout.weight(.medium))
                    if kind.isCore {
                        Pill(text: "Core", tint: .blue)
                    }
                    if document?.isStale == true {
                        Pill(text: "Stale", tint: .red)
                    }
                }
                if let doc = document, doc.present {
                    HStack(spacing: 8) {
                        if !doc.attorney.isEmpty {
                            Text(doc.attorney).font(.caption2).foregroundStyle(.secondary)
                        }
                        if !doc.location.isEmpty {
                            Text("· \(doc.location)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                        }
                        if let years = doc.yearsSinceReview {
                            Text("· Reviewed \(years)y ago").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            Spacer()
            Button("Edit") { onEdit() }.buttonStyle(.bordered).controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
    }
}

struct EditEstateDocSheet: View {
    @Bindable var document: EstateDocument

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: document.kind.systemImage).foregroundStyle(Color.blue)
                Text(document.kind.displayName).font(.title3.weight(.semibold))
            }
            Toggle("Document is in place", isOn: $document.present).toggleStyle(.switch)
            VStack(alignment: .leading, spacing: 4) {
                Text("ATTORNEY / DRAFTER").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Optional", text: $document.attorney).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("PHYSICAL / DIGITAL LOCATION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Safe / 1Password vault / law firm", text: $document.location).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("LAST REVIEWED").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                DatePicker("", selection: Binding(
                    get: { document.lastReviewedAt ?? Date() },
                    set: { document.lastReviewedAt = $0 }
                ), displayedComponents: [.date]).labelsHidden()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTES").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextEditor(text: $document.note)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.25)))
            }
            Spacer()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    document.updatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
    }
}
