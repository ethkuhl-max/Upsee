import SwiftUI
import SwiftData

struct DecisionLogList: View {
    let entries: [DecisionEntity]

    @Environment(\.modelContext) private var modelContext
    @State private var editingOutcome: DecisionEntity?

    private var matchRate: Double {
        guard !entries.isEmpty else { return 0 }
        let matched = entries.filter { $0.matchedRecommendation }.count
        return Double(matched) / Double(entries.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                stat("Logged", "\(entries.count)")
                stat("Match rate", String(format: "%.0f%%", matchRate * 100), tint: matchRate >= 0.5 ? .green : .orange)
                let withOutcome = entries.filter { !$0.outcome.isEmpty }.count
                stat("Reviewed", "\(withOutcome) / \(entries.count)")
                Spacer()
            }
            ForEach(entries) { entry in
                row(for: entry)
            }
        }
        .sheet(item: $editingOutcome) { entry in
            OutcomeEditSheet(entry: entry).frame(minWidth: 460, minHeight: 320)
        }
    }

    private func row(for entry: DecisionEntity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: entry.kind.systemImage).foregroundStyle(entry.kind.tint)
                Text(entry.targetLabel).font(.callout.weight(.medium))
                Spacer()
                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    modelContext.delete(entry)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                miniLabel("Suggested", entry.recommendation, tint: .secondary)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                miniLabel("Chose", entry.userChoice, tint: entry.matchedRecommendation ? .blue : .orange)
            }
            if !entry.rationale.isEmpty {
                Text(entry.rationale).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if entry.outcome.isEmpty {
                    Button {
                        editingOutcome = entry
                    } label: {
                        Label("Add outcome", systemImage: "flag.checkered")
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered.circle.fill").foregroundStyle(Color.purple)
                        Text(entry.outcome).font(.caption).foregroundStyle(.primary)
                    }
                    Button("Edit") { editingOutcome = entry }
                        .buttonStyle(.borderless).controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private func miniLabel(_ label: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium)).foregroundStyle(tint)
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(tint)
        }
    }
}

private struct OutcomeEditSheet: View {
    let entry: DecisionEntity

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var outcomeText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Retrospective").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("DECISION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(entry.targetLabel) — chose \(entry.userChoice) over \(entry.recommendation)")
                    .font(.callout)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("HOW IT PLAYED OUT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextEditor(text: $outcomeText)
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.3)))
            }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    entry.outcome = outcomeText
                    entry.outcomeUpdatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(outcomeText.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .onAppear { outcomeText = entry.outcome }
    }
}
