import SwiftUI
import SwiftData

struct RoadmapItemRow: View {
    @Bindable var item: RoadmapItem
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Menu {
                ForEach(RoadmapStatus.allCases, id: \.self) { s in
                    Button(s.displayName) {
                        item.status = s
                        item.updatedAt = Date()
                        try? modelContext.save()
                    }
                }
            } label: {
                Image(systemName: statusSymbol(item.status))
                    .font(.title3)
                    .foregroundStyle(item.status.tint)
                    .frame(width: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.callout.weight(.medium))
                        .strikethrough(item.status == .done || item.status == .scrapped)
                    if item.priority == .high {
                        Image(systemName: item.priority.symbol).foregroundStyle(item.priority.tint)
                    }
                    Spacer()
                    if let version = item.targetVersion, !version.isEmpty {
                        Text("v\(version)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    if let est = item.estimatedHours {
                        Text("\(format(est))h").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                }
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Button(role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private func statusSymbol(_ s: RoadmapStatus) -> String {
        switch s {
        case .idea: return "lightbulb"
        case .planned: return "circle"
        case .inProgress: return "circle.bottomhalf.filled"
        case .done: return "checkmark.circle.fill"
        case .scrapped: return "xmark.circle"
        }
    }

    private func format(_ d: Double) -> String {
        if d == d.rounded() { return String(Int(d)) }
        return String(format: "%.1f", d)
    }
}

struct AddRoadmapSheet: View {
    let app: AppEntity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var status: RoadmapStatus = .planned
    @State private var priority: RoadmapPriority = .medium
    @State private var targetVersion = ""
    @State private var estimatedHours = ""

    private var canSave: Bool { !title.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Roadmap Item").font(.title3.weight(.semibold))
            Text(app.name).font(.callout).foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Title", text: $title, placeholder: "Ship the CFI onboarding email")
                    detailField("Detail", text: $detail, placeholder: "Optional — context, links, acceptance criteria")
                    HStack(spacing: 14) {
                        picker("Status", selection: $status) {
                            ForEach(RoadmapStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        picker("Priority", selection: $priority) {
                            ForEach(RoadmapPriority.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                    field("Target version", text: $targetVersion, placeholder: "0.4 (optional)")
                    field("Estimated hours", text: $estimatedHours, placeholder: "0 (optional)")
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
        let item = RoadmapItem(
            title: title,
            detail: detail,
            status: status,
            priority: priority,
            targetVersion: targetVersion.isEmpty ? nil : targetVersion,
            estimatedHours: Double(estimatedHours)
        )
        item.app = app
        modelContext.insert(item)
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
    private func detailField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.callout)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
        }
    }

    @ViewBuilder
    private func picker<T: Hashable, C: View>(
        _ label: String,
        selection: Binding<T>,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Picker(label, selection: selection) { content() }
                .labelsHidden()
                .pickerStyle(.menu)
        }
    }
}
