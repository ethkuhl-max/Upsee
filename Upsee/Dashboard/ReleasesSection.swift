import SwiftUI
import SwiftData

struct ReleaseRow: View {
    @Bindable var release: ReleaseEntry
    @Environment(\.modelContext) private var modelContext

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("v\(release.version)")
                    .font(.callout.monospaced().weight(.semibold))
                Text(Self.dateFormatter.string(from: release.releasedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    modelContext.delete(release)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            if !release.summary.isEmpty {
                Text(release.summary).font(.callout)
            }
            if !release.highlightLines.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(release.highlightLines, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•").foregroundStyle(.secondary)
                            Text(line).font(.caption)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }
}

struct AddReleaseSheet: View {
    let app: AppEntity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var version = ""
    @State private var releasedAt = Date()
    @State private var summary = ""
    @State private var highlights = ""
    @State private var notes = ""
    @State private var markAppShipped = true

    private var canSave: Bool { !version.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Release").font(.title3.weight(.semibold))
            Text(app.name).font(.callout).foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Version", text: $version, placeholder: "0.3.1")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Released").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        DatePicker("Released", selection: $releasedAt, displayedComponents: [.date])
                            .labelsHidden()
                    }
                    field("Summary", text: $summary, placeholder: "One-line description of the release")
                    multilineField("Highlights", text: $highlights, placeholder: "One bullet per line — what shipped, what changed")
                    multilineField("Notes", text: $notes, placeholder: "Internal notes, follow-ups")
                    Toggle("Update app's last-shipped date", isOn: $markAppShipped)
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func save() {
        let release = ReleaseEntry(
            version: version,
            releasedAt: releasedAt,
            summary: summary,
            highlights: highlights,
            notes: notes
        )
        release.app = app
        modelContext.insert(release)
        if markAppShipped {
            app.lastShippedAt = releasedAt
            app.updatedAt = Date()
        }
        try? modelContext.save()
        dismiss()
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func multilineField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.callout)
                .frame(minHeight: 70, maxHeight: 120)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
        }
    }
}
