import SwiftUI
import SwiftData

struct WeeklyCommitmentSection: View {
    let app: AppEntity
    let timeEntries: [TimeEntry]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeeklyCommitment.weekStart, order: .reverse) private var allCommitments: [WeeklyCommitment]

    @State private var addingNew = false
    @State private var closingCommitment: WeeklyCommitment?

    private var appCommitments: [WeeklyCommitment] {
        allCommitments.filter { $0.entityKind == "app" && $0.entityLabel == app.name }
    }

    private var currentCommitment: WeeklyCommitment? {
        appCommitments.first { $0.isCurrentWeek }
    }

    private var pastCommitments: [WeeklyCommitment] {
        appCommitments.filter { !$0.isCurrentWeek }.prefix(4).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let current = currentCommitment {
                CurrentCommitmentCard(
                    commitment: current,
                    actualHours: actualHours(for: current),
                    onClose: { closingCommitment = current }
                )
            } else {
                Button {
                    addingNew = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill").foregroundStyle(Color.blue)
                        Text("Set this week's focus for \(app.name)")
                            .font(.callout.weight(.medium))
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            if !pastCommitments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PAST WEEKS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(pastCommitments) { commitment in
                        PastCommitmentRow(commitment: commitment, actualHours: actualHours(for: commitment))
                    }
                }
            }
        }
        .sheet(isPresented: $addingNew) {
            AddWeeklyCommitmentSheet(app: app).frame(minWidth: 520, minHeight: 380)
        }
        .sheet(item: $closingCommitment) { commitment in
            CloseWeeklyCommitmentSheet(commitment: commitment).frame(minWidth: 480, minHeight: 380)
        }
    }

    private func actualHours(for commitment: WeeklyCommitment) -> Double {
        timeEntries
            .filter {
                $0.entityKind == "app"
                && $0.entityLabel == app.name
                && $0.startedAt >= commitment.weekStart
                && $0.startedAt < commitment.weekEnd
            }
            .reduce(0.0) { $0 + $1.hours }
    }
}

private struct CurrentCommitmentCard: View {
    let commitment: WeeklyCommitment
    let actualHours: Double
    let onClose: () -> Void

    private var progress: Double {
        guard commitment.hoursTarget > 0 else { return 0 }
        return min(1.0, actualHours / Double(commitment.hoursTarget))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill").foregroundStyle(Color.blue)
                Text("This week").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Pill(text: commitment.status.displayName, tint: commitment.status.tint)
            }
            Text(commitment.commitment).font(.callout.weight(.medium))
            if commitment.hoursTarget > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(String(format: "%.1f", actualHours))h logged")
                            .font(.caption.monospacedDigit())
                        Text("/ \(commitment.hoursTarget)h target")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(progress >= 1.0 ? Color.green : Color.secondary)
                    }
                    ProgressView(value: progress).tint(progress >= 1.0 ? Color.green : Color.blue)
                }
            }
            HStack {
                Spacer()
                Button("Close week", action: onClose).buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.blue.opacity(0.2)))
    }
}

private struct PastCommitmentRow: View {
    let commitment: WeeklyCommitment
    let actualHours: Double

    var body: some View {
        HStack(spacing: 10) {
            Pill(text: commitment.status.displayName, tint: commitment.status.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(commitment.commitment).font(.caption.weight(.medium))
                Text(commitment.weekStart.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if commitment.hoursTarget > 0 {
                Text("\(String(format: "%.1f", actualHours))h / \(commitment.hoursTarget)h")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.05)))
    }
}

struct AddWeeklyCommitmentSheet: View {
    let app: AppEntity

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var commitment: String = ""
    @State private var hoursTarget: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set this week's focus").font(.title3.weight(.semibold))
            Text("\(app.name) — week of \(WeekStart.of(Date()).formatted(date: .abbreviated, time: .omitted))")
                .font(.callout).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("THE FOCUS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Ship onboarding revamp / Talk to 5 users / Refactor data layer", text: $commitment)
                    .textFieldStyle(.roundedBorder)
            }

            Stepper("Target: \(hoursTarget)h this week", value: $hoursTarget, in: 0...60, step: 1)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Set commitment") {
                    let c = WeeklyCommitment(
                        weekStart: WeekStart.of(Date()),
                        entityKind: "app",
                        entityLabel: app.name,
                        commitment: commitment,
                        hoursTarget: hoursTarget,
                        status: .inProgress
                    )
                    modelContext.insert(c)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commitment.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
    }
}

struct CloseWeeklyCommitmentSheet: View {
    @Bindable var commitment: WeeklyCommitment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var outcomeText: String = ""
    @State private var chosenStatus: WeeklyCommitmentStatus = .hit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Close the week").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("COMMITMENT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(commitment.commitment).font(.callout)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("OUTCOME").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Status", selection: $chosenStatus) {
                    ForEach([WeeklyCommitmentStatus.hit, .missed, .dropped], id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("WHAT ACTUALLY HAPPENED").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextEditor(text: $outcomeText)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.3)))
            }
            Spacer()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    commitment.outcome = outcomeText
                    commitment.status = chosenStatus
                    commitment.updatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .onAppear { outcomeText = commitment.outcome }
    }
}
