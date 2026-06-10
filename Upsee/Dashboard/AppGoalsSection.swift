import SwiftUI
import SwiftData

struct AppGoalRow: View {
    @Bindable var goal: AppGoal
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Menu {
                    ForEach(AppGoalStatus.allCases, id: \.self) { s in
                        Button(s.displayName) {
                            goal.status = s
                            goal.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                } label: {
                    Pill(text: goal.status.displayName, tint: goal.status.tint)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Text(goal.title).font(.callout.weight(.medium))
                Spacer()
                if let date = goal.targetDate {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    modelContext.delete(goal)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            if let summary = goal.quantifiableSummary {
                HStack {
                    Text(summary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let progress = goal.progress {
                        ProgressView(value: progress)
                            .tint(goal.status.tint)
                            .frame(maxWidth: 220)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }
}

struct AddAppGoalSheet: View {
    let app: AppEntity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var unit = ""
    @State private var targetValue = ""
    @State private var currentValue = ""
    @State private var hasTargetDate = true
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 90)

    private var canSave: Bool { !title.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Goal").font(.title3.weight(.semibold))
            Text(app.name).font(.callout).foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Title", text: $title, placeholder: "100 paying CFIs / $500 MRR / TestFlight beta launch")
                    HStack(spacing: 14) {
                        field("Target", text: $targetValue, placeholder: "Optional")
                        field("Current", text: $currentValue, placeholder: "Optional")
                        field("Unit", text: $unit, placeholder: "users / MRR / etc.")
                    }
                    Toggle("Set target date", isOn: $hasTargetDate).toggleStyle(.switch)
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
        let goal = AppGoal(
            title: title,
            targetValue: Double(targetValue),
            currentValue: Double(currentValue),
            unit: unit,
            targetDate: hasTargetDate ? targetDate : nil
        )
        goal.app = app
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
}

struct EditAppSheet: View {
    @Bindable var app: AppEntity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var revenueText = ""
    @State private var usersText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit \(app.name)").font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Name", text: $app.name, placeholder: "App name")
                    field("Summary", text: $app.summary, placeholder: "One-line summary")
                    field("Repo path", text: Binding(get: { app.repoPath ?? "" }, set: { app.repoPath = $0.isEmpty ? nil : $0 }), placeholder: "~/code/...")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Status", selection: Binding(get: { app.status }, set: { app.status = $0 })) {
                            ForEach(AppStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.menu).labelsHidden()
                    }
                    field("Monthly revenue", text: $revenueText, placeholder: "0")
                        .monospacedDigit()
                    field("Active users", text: $usersText, placeholder: "0")
                        .monospacedDigit()
                    field("Marketing note", text: $app.marketingNote, placeholder: "Current marketing status")
                    field("Tech debt note", text: $app.techDebtNote, placeholder: "Known issues")
                }
            }

            HStack {
                Button("Delete app", role: .destructive) {
                    modelContext.delete(app)
                    try? modelContext.save()
                    dismiss()
                }
                Spacer()
                Button("Done") {
                    app.monthlyRevenue = parseDecimal(revenueText)
                    app.activeUsers = Int(usersText) ?? app.activeUsers
                    app.updatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            revenueText = String(NSDecimalNumber(decimal: app.monthlyRevenue).doubleValue)
            usersText = String(app.activeUsers)
        }
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
