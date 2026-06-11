import SwiftUI
import SwiftData

struct RetrospectiveBanner: View {
    let staleDecisions: [DecisionEntity]
    @Binding var reviewing: DecisionEntity?

    private var firstThree: [DecisionEntity] {
        Array(staleDecisions.prefix(3))
    }

    var body: some View {
        if staleDecisions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.diamond.fill").foregroundStyle(Color.orange)
                    Text("\(staleDecisions.count) decision\(staleDecisions.count == 1 ? "" : "s") need a retrospective")
                        .font(.callout.weight(.semibold))
                    Spacer()
                }
                Text("These are 30+ days old without an outcome. Grade them while it's still fresh — your hit rate is only honest if you close the loop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(firstThree) { decision in
                        Button {
                            reviewing = decision
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: decision.kind.systemImage).foregroundStyle(decision.kind.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(decision.targetLabel).font(.caption.weight(.medium)).foregroundStyle(.primary)
                                    Text("Chose \(decision.userChoice) — recommended \(decision.recommendation)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(daysOld(decision))d").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.001)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if staleDecisions.count > 3 {
                    Text("+\(staleDecisions.count - 3) more in the log below")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.25)))
        }
    }

    private func daysOld(_ decision: DecisionEntity) -> Int {
        Calendar.current.dateComponents([.day], from: decision.createdAt, to: Date()).day ?? 0
    }
}

struct RetrospectiveOutcomeSheet: View {
    @Bindable var decision: DecisionEntity

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var outcomeText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Retrospective").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("DECISION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(decision.targetLabel) — chose \(decision.userChoice) over \(decision.recommendation)")
                    .font(.callout)
                if !decision.rationale.isEmpty {
                    Text("Rationale at the time: \(decision.rationale)").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
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
                    decision.outcome = outcomeText
                    decision.outcomeUpdatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(outcomeText.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .onAppear { outcomeText = decision.outcome }
    }
}
