import SwiftUI
import SwiftData

/// Working tracker for a deal: due-diligence checklist (with an industry template),
/// free-form notes, and a follow-up date.
struct DealDiligenceView: View {
    let deal: DealEntity

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [DiligenceItem]

    @State private var newItemText = ""

    init(deal: DealEntity) {
        self.deal = deal
        let id = deal.dealID
        _items = Query(
            filter: #Predicate<DiligenceItem> { $0.dealID == id },
            sort: [SortDescriptor(\DiligenceItem.sortIndex)]
        )
    }

    private var completedCount: Int { items.filter(\.isDone).count }
    private var progress: Double { items.isEmpty ? 0 : Double(completedCount) / Double(items.count) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                followUpSection
                notesSection
                checklistSection
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    // MARK: - Follow-up

    private var followUpSection: some View {
        sectionShell("Follow-up") {
            HStack {
                Toggle("Set a follow-up date", isOn: Binding(
                    get: { deal.followUpDate != nil },
                    set: { on in
                        deal.followUpDate = on ? (deal.followUpDate ?? Date()) : nil
                        deal.updatedAt = Date()
                        try? modelContext.save()
                        syncReminder()
                    }
                ))
                .toggleStyle(.switch)
                Spacer()
                if deal.followUpDate != nil {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { deal.followUpDate ?? Date() },
                            set: { deal.followUpDate = $0; deal.updatedAt = Date(); try? modelContext.save(); syncReminder() }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
            }
            if deal.followUpDate != nil {
                Text("A reminder will notify you that morning.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func syncReminder() {
        if let date = deal.followUpDate {
            NotificationService.scheduleDealFollowUp(dealID: deal.dealID, businessName: deal.businessName, date: date)
        } else {
            NotificationService.cancelDealFollowUp(dealID: deal.dealID)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        sectionShell("Notes") {
            TextEditor(text: Binding(
                get: { deal.note },
                set: { deal.note = $0; deal.updatedAt = Date(); try? modelContext.save() }
            ))
            .font(.callout)
            .frame(minHeight: 120)
            .padding(8)
            .glassPanel(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15))
            )
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        sectionShell("Due-diligence checklist") {
            VStack(alignment: .leading, spacing: 12) {
                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No checklist yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button {
                            loadTemplate()
                        } label: {
                            Label("Load \(deal.industry.displayName) template", systemImage: "list.bullet.clipboard")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    HStack {
                        ProgressView(value: progress)
                            .frame(maxWidth: 220)
                        Text("\(completedCount)/\(items.count) done")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    ForEach(items) { item in
                        checklistRow(item)
                    }
                }

                HStack {
                    TextField("Add a diligence item…", text: $newItemText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addItem)
                    Button(action: addItem) {
                        Image(systemName: "plus")
                    }
                    .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func checklistRow(_ item: DiligenceItem) -> some View {
        HStack(spacing: 10) {
            Button {
                item.isDone.toggle()
                try? modelContext.save()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(.callout)
                .strikethrough(item.isDone, color: .secondary)
                .foregroundStyle(item.isDone ? .secondary : .primary)

            Spacer()

            Button(role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }

    // MARK: - Actions

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let item = DiligenceItem(dealID: deal.dealID, text: text, sortIndex: items.count)
        modelContext.insert(item)
        try? modelContext.save()
        newItemText = ""
    }

    private func loadTemplate() {
        for (index, text) in DiligenceTemplate.items(for: deal.industry).enumerated() {
            modelContext.insert(DiligenceItem(dealID: deal.dealID, text: text, sortIndex: index))
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func sectionShell<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }
}
