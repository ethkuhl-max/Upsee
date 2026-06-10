import SwiftUI
import SwiftData

struct LogDecisionSheet: View {
    let target: LogTarget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var userChoice: String = ""
    @State private var rationale: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: target.kind.systemImage)
                    .foregroundStyle(target.kind.tint)
                Text("Log decision — \(target.kind.displayName.lowercased())")
                    .font(.title3.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("TARGET").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(target.label).font(.callout.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("MODEL RECOMMENDATION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(target.recommendation).font(.callout)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR CHOICE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("E.g. Grow / Hold / Kill / Take it / Walk", text: $userChoice)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 6) {
                    Button("Match recommendation") {
                        userChoice = target.recommendation
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("WHY (FUTURE-YOU WILL THANK YOU)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextEditor(text: $rationale)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.3)))
            }

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let decision = DecisionEntity(
                        kind: target.kind,
                        targetLabel: target.label,
                        recommendation: target.recommendation,
                        userChoice: userChoice,
                        rationale: rationale
                    )
                    modelContext.insert(decision)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(userChoice.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
