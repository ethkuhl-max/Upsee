import SwiftUI
import SwiftData

/// Drives the add/edit sheet for dashboard entities. A `nil` payload means "create new";
/// a non-nil payload pre-fills the form and edits that entity in place.
enum EntityEditor: Identifiable {
    case app(AppEntity?)
    case job(JobEntity?)
    case personal(PersonalEntity?)

    var id: String {
        switch self {
        case .app(let e): return "app-\(e.map { ObjectIdentifier($0).hashValue } ?? 0)"
        case .job(let e): return "job-\(e.map { ObjectIdentifier($0).hashValue } ?? 0)"
        case .personal(let e): return "personal-\(e.map { ObjectIdentifier($0).hashValue } ?? 0)"
        }
    }
}

struct AddEntitySheet: View {
    let editor: EntityEditor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch editor {
        case .app(let existing):
            AppForm(existing: existing, onSave: { save($0, isNew: existing == nil) }, onCancel: { dismiss() })
        case .job(let existing):
            JobForm(existing: existing, onSave: { save($0, isNew: existing == nil) }, onCancel: { dismiss() })
        case .personal(let existing):
            PersonalForm(existing: existing, onSave: { save($0, isNew: existing == nil) }, onCancel: { dismiss() })
        }
    }

    private func save<T: PersistentModel>(_ entity: T, isNew: Bool) {
        if isNew { modelContext.insert(entity) }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - App form

private struct AppForm: View {
    let existing: AppEntity?
    let onSave: (AppEntity) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var summary = ""
    @State private var status: AppStatus = .active
    @State private var repoPath = ""
    @State private var monthlyRevenue = ""
    @State private var activeUsers = ""
    @State private var marketingNote = ""

    var body: some View {
        FormShell(title: existing == nil ? "Add an App" : "Edit App", onCancel: onCancel, canSave: !name.isEmpty, onSave: save) {
            LabeledField("Name", text: $name, placeholder: "Weather.Co")
            LabeledField("Summary", text: $summary, placeholder: "What is this app, in one line?")
            LabeledPicker("Status", selection: $status) {
                ForEach(AppStatus.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }
            LabeledField("Repo path", text: $repoPath, placeholder: "~/code/weatherco (optional)")
            LabeledField("Monthly revenue", text: $monthlyRevenue, placeholder: "0")
                .monospacedDigit()
            LabeledField("Active users", text: $activeUsers, placeholder: "0")
                .monospacedDigit()
            LabeledField("Marketing note", text: $marketingNote, placeholder: "What's happening on the distribution side?")
        }
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        guard let e = existing else { return }
        name = e.name
        summary = e.summary
        status = e.status
        repoPath = e.repoPath ?? ""
        monthlyRevenue = formatDecimal(e.monthlyRevenue)
        activeUsers = "\(e.activeUsers)"
        marketingNote = e.marketingNote
    }

    private func save() {
        let entity = existing ?? AppEntity(name: name)
        entity.name = name
        entity.summary = summary
        entity.status = status
        entity.repoPath = repoPath.isEmpty ? nil : repoPath
        entity.monthlyRevenue = parseDecimal(monthlyRevenue)
        entity.activeUsers = Int(activeUsers) ?? 0
        entity.marketingNote = marketingNote
        entity.updatedAt = Date()
        onSave(entity)
    }
}

// MARK: - Job form

private struct JobForm: View {
    let existing: JobEntity?
    let onSave: (JobEntity) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var employer = ""
    @State private var status: JobStatus = .pending
    @State private var monthlyComp = ""
    @State private var hoursPerWeek = "40"
    @State private var note = ""

    var body: some View {
        FormShell(title: existing == nil ? "Add a Job" : "Edit Job", onCancel: onCancel, canSave: !title.isEmpty && !employer.isEmpty, onSave: save) {
            LabeledField("Title", text: $title, placeholder: "Senior Engineer")
            LabeledField("Employer", text: $employer, placeholder: "Company name")
            LabeledPicker("Status", selection: $status) {
                ForEach(JobStatus.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }
            LabeledField("Monthly compensation", text: $monthlyComp, placeholder: "0")
                .monospacedDigit()
            LabeledField("Hours per week", text: $hoursPerWeek, placeholder: "40")
                .monospacedDigit()
            LabeledField("Note", text: $note, placeholder: "Optional")
        }
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        guard let e = existing else { return }
        title = e.title
        employer = e.employer
        status = e.status
        monthlyComp = formatDecimal(e.monthlyCompensation)
        hoursPerWeek = "\(e.hoursPerWeek)"
        note = e.note
    }

    private func save() {
        let entity = existing ?? JobEntity(title: title, employer: employer)
        entity.title = title
        entity.employer = employer
        entity.status = status
        entity.monthlyCompensation = parseDecimal(monthlyComp)
        entity.hoursPerWeek = Int(hoursPerWeek) ?? 40
        entity.note = note
        entity.updatedAt = Date()
        onSave(entity)
    }
}

// MARK: - Personal form

private struct PersonalForm: View {
    let existing: PersonalEntity?
    let onSave: (PersonalEntity) -> Void
    let onCancel: () -> Void

    @State private var monthlyIncome = ""
    @State private var monthlyExpenses = ""
    @State private var currentSavings = ""
    @State private var taxBracket = "24"
    @State private var note = ""
    @State private var filingStatus: FilingStatus = .single
    @State private var stateRate = "0"
    @State private var selfEmploymentPortion = "0"

    var body: some View {
        FormShell(title: existing == nil ? "Set Personal Profile" : "Edit Personal Profile", onCancel: onCancel, canSave: true, onSave: save) {
            LabeledField("Monthly income", text: $monthlyIncome, placeholder: "0")
                .monospacedDigit()
            LabeledField("Monthly expenses", text: $monthlyExpenses, placeholder: "0")
                .monospacedDigit()
            LabeledField("Current savings", text: $currentSavings, placeholder: "0")
                .monospacedDigit()
            LabeledField("Tax bracket (%)", text: $taxBracket, placeholder: "24")
                .monospacedDigit()
            LabeledPicker("Filing status", selection: $filingStatus) {
                ForEach(FilingStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            LabeledField("State tax rate (%)", text: $stateRate, placeholder: "0")
                .monospacedDigit()
            LabeledField("Self-employed income (%)", text: $selfEmploymentPortion, placeholder: "0")
                .monospacedDigit()
            LabeledField("Note", text: $note, placeholder: "Optional")
        }
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        guard let e = existing else { return }
        monthlyIncome = formatDecimal(e.monthlyIncome)
        monthlyExpenses = formatDecimal(e.monthlyExpenses)
        currentSavings = formatDecimal(e.currentSavings)
        taxBracket = String(format: "%.0f", e.taxBracketEstimate * 100)
        filingStatus = e.filingStatus
        stateRate = String(format: "%.1f", e.stateTaxRate * 100)
        selfEmploymentPortion = String(format: "%.0f", e.selfEmploymentPortion * 100)
        note = e.note
    }

    private func save() {
        let entity = existing ?? PersonalEntity()
        entity.monthlyIncome = parseDecimal(monthlyIncome)
        entity.monthlyExpenses = parseDecimal(monthlyExpenses)
        entity.currentSavings = parseDecimal(currentSavings)
        entity.taxBracketEstimate = (Double(taxBracket) ?? 24) / 100.0
        entity.filingStatus = filingStatus
        entity.stateTaxRate = (Double(stateRate) ?? 0) / 100.0
        entity.selfEmploymentPortion = min(1, max(0, (Double(selfEmploymentPortion) ?? 0) / 100.0))
        entity.note = note
        entity.updatedAt = Date()
        onSave(entity)
    }
}

// MARK: - Shared form shell

private struct FormShell<Content: View>: View {
    let title: String
    let onCancel: () -> Void
    let canSave: Bool
    let onSave: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.title3.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
            }
            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Spacer()
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct LabeledPicker<SelectionValue: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: SelectionValue
    @ViewBuilder var content: () -> Content

    init(_ label: String, selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self._selection = selection
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(label, selection: $selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

private func parseDecimal(_ s: String) -> Decimal {
    let cleaned = s.replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: ",", with: "")
        .trimmingCharacters(in: .whitespaces)
    return Decimal(string: cleaned) ?? 0
}

private func formatDecimal(_ d: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.groupingSeparator = ""
    return formatter.string(from: NSDecimalNumber(decimal: d)) ?? "0"
}
