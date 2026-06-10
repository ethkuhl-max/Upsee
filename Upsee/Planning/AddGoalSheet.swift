import SwiftUI
import SwiftData

struct AddGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var summary = ""
    @State private var targetAmount = ""
    @State private var currentAmount = "0"
    @State private var hasTargetDate = false
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 365)

    private var canSave: Bool { !name.isEmpty && parseDecimal(targetAmount) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Goal").font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Name", text: $name, placeholder: "Down payment / emergency fund / etc.")
                    field("Summary", text: $summary, placeholder: "Optional")
                    field("Target amount", text: $targetAmount, placeholder: "0")
                    field("Current amount", text: $currentAmount, placeholder: "0")

                    Toggle("Set target date", isOn: $hasTargetDate)
                        .toggleStyle(.switch)
                    if hasTargetDate {
                        DatePicker("Target date", selection: $targetDate, displayedComponents: [.date])
                    }
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
        let goal = GoalEntity(
            name: name,
            summary: summary,
            targetAmount: parseDecimal(targetAmount),
            currentAmount: parseDecimal(currentAmount),
            targetDate: hasTargetDate ? targetDate : nil
        )
        modelContext.insert(goal)
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

    private func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}
