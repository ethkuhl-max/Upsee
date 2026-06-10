import SwiftUI
import SwiftData
import Charts

/// The Health pillar: founder wellbeing check-ins, a burnout-risk read that pulls from
/// time-tracked hours, habit streaks, and a synthesized financial-health score.
struct HealthView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WellbeingEntry.date, order: .reverse) private var wellbeing: [WellbeingEntry]
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]
    @Query private var timeEntries: [TimeEntry]
    @Query private var apps: [AppEntity]
    @Query private var jobs: [JobEntity]
    @Query private var personal: [PersonalEntity]
    @Query private var balanceSheetItems: [BalanceSheetItem]

    @State private var addingHabit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                burnoutSection
                checkInSection
                if recentEntries.count >= 2 { trendsSection }
                habitsSection
                financialHealthSection
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .navigationTitle("Health")
        .sheet(isPresented: $addingHabit) {
            AddHabitSheet(nextIndex: habits.count).frame(minWidth: 420, minHeight: 360)
        }
    }

    // MARK: - Burnout

    private var burnout: BurnoutAssessment {
        BurnoutEngine.assess(entries: recentSamples, weeklyWorkHours: weeklyWorkHours)
    }

    private var burnoutSection: some View {
        let b = burnout
        return section("Burnout risk") {
            HStack(alignment: .top, spacing: 20) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 10).frame(width: 96, height: 96)
                    Circle().trim(from: 0, to: CGFloat(b.score) / 100)
                        .stroke(b.band.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                    VStack(spacing: 0) {
                        Text("\(b.score)").font(.title2.monospacedDigit().weight(.semibold))
                        Text("/100").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Pill(text: b.band.label, tint: b.band.tint)
                    Text("\(Int(weeklyWorkHours))h logged this week.")
                        .font(.callout).foregroundStyle(.secondary)
                    if b.drivers.isEmpty {
                        Text("No major risk factors right now — keep it up.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        ForEach(b.drivers, id: \.self) { driver in
                            Label(driver, systemImage: "exclamationmark.circle")
                                .font(.callout).foregroundStyle(b.band.tint)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Daily check-in

    private var checkInSection: some View {
        section("Today's check-in") {
            VStack(alignment: .leading, spacing: 14) {
                ratingRow("Energy", value: energyBinding, low: "Drained", high: "Energized")
                ratingRow("Stress", value: stressBinding, low: "Calm", high: "Overwhelmed")
                HStack(spacing: 12) {
                    Text("Sleep").font(.callout).frame(width: 90, alignment: .leading)
                    Slider(value: sleepBinding, in: 0...12, step: 0.5)
                    Text(String(format: "%.1fh", todayEntry?.sleepHours ?? 7.5))
                        .font(.callout.monospacedDigit()).frame(width: 56, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Text("Exercise").font(.callout).frame(width: 90, alignment: .leading)
                    Slider(value: exerciseBinding, in: 0...120, step: 5)
                    Text("\(todayEntry?.exerciseMinutes ?? 0)m")
                        .font(.callout.monospacedDigit()).frame(width: 56, alignment: .trailing)
                }
                if todayEntry == nil {
                    Text("Adjust any slider to log today's check-in.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
        }
    }

    private func ratingRow(_ label: String, value: Binding<Double>, low: String, high: String) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.callout).frame(width: 90, alignment: .leading)
            ForEach(1...5, id: \.self) { i in
                Button {
                    value.wrappedValue = Double(i)
                } label: {
                    Circle()
                        .fill(Int(value.wrappedValue) >= i ? Color.accentColor : Color.secondary.opacity(0.18))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            Text("\(low) → \(high)").font(.caption2).foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Trends

    private var trendsSection: some View {
        section("Last 14 days") {
            Chart {
                ForEach(recentEntries) { e in
                    LineMark(x: .value("Day", e.date), y: .value("Energy", e.energy), series: .value("Metric", "Energy"))
                        .foregroundStyle(.green)
                    LineMark(x: .value("Day", e.date), y: .value("Stress", e.stress), series: .value("Metric", "Stress"))
                        .foregroundStyle(.orange)
                }
            }
            .chartForegroundStyleScale(["Energy": Color.green, "Stress": Color.orange])
            .chartYScale(domain: 1...5)
            .frame(height: 160)
        }
    }

    // MARK: - Habits

    private var habitsSection: some View {
        section("Habits") {
            VStack(alignment: .leading, spacing: 10) {
                if habits.isEmpty {
                    Text("No habits yet. Track routines like deep work, workouts, or a sleep schedule.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(habits) { habit in
                        habitRow(habit)
                    }
                }
                Button { addingHabit = true } label: { Label("Add habit", systemImage: "plus") }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let streak = HabitStreakEngine.compute(completedDayKeys: habit.completionDayKeys)
        return HStack(spacing: 12) {
            Button {
                habit.toggle(on: Date())
                try? modelContext.save()
            } label: {
                Image(systemName: streak.doneToday ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(streak.doneToday ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: habit.systemImage).foregroundStyle(.secondary).frame(width: 22)
            Text(habit.name).font(.callout)
            Spacer()
            if streak.currentStreak > 0 {
                Label("\(streak.currentStreak)", systemImage: "flame.fill")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Text(String(format: "%.0f%%", streak.completionRate30 * 100))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(habit)
                try? modelContext.save()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Financial health

    private var financialHealth: FinancialHealth {
        FinancialHealthEngine.assess(financialInputs)
    }

    private var financialHealthSection: some View {
        let h = financialHealth
        return section("Financial health") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 18) {
                    VStack(spacing: 0) {
                        Text(h.grade).font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(gradeTint(h.overall))
                        Text("\(h.overall)/100").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .frame(width: 90)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(h.subscores) { sub in
                            HStack(spacing: 8) {
                                Text(sub.name).font(.callout).frame(width: 130, alignment: .leading)
                                ProgressView(value: Double(sub.score) / 100).tint(gradeTint(sub.score))
                                Text(sub.detail).font(.caption2).foregroundStyle(.secondary).frame(width: 150, alignment: .trailing)
                            }
                        }
                    }
                }
                if !h.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(h.recommendations, id: \.self) { rec in
                            Label(rec, systemImage: "lightbulb").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var financialInputs: FinancialHealthInputs {
        let me = personal.first
        let monthlyIncome = CashFlowEngine.aggregateMonthlyIncome(jobs: jobs, apps: apps, personal: me)
        let netWorth = NetWorthEngine.summarize(balanceSheetItems)

        let liquid = balanceSheetItems
            .filter { $0.category == .cash || $0.category == .investments }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let liquidSavings = liquid > 0 ? liquid : (me?.currentSavings ?? 0)
        let debtPayments = balanceSheetItems.filter { !$0.isAsset }.reduce(Decimal(0)) { $0 + $1.minimumPayment }

        let jobInc = dbl(jobs.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.monthlyCompensation })
        let appInc = dbl(apps.reduce(Decimal(0)) { $0 + $1.monthlyRevenue })
        let otherInc = dbl(me?.monthlyIncome ?? 0)
        let totalInc = jobInc + appInc + otherInc
        let largestShare = totalInc > 0 ? max(jobInc, appInc, otherInc) / totalInc : 0

        return FinancialHealthInputs(
            monthlyIncome: monthlyIncome,
            monthlyExpenses: me?.monthlyExpenses ?? 0,
            liquidSavings: liquidSavings,
            totalAssets: netWorth.totalAssets,
            totalLiabilities: netWorth.totalLiabilities,
            monthlyDebtPayments: debtPayments,
            largestIncomeShare: largestShare
        )
    }

    // MARK: - Derived wellbeing data

    private var todayEntry: WellbeingEntry? {
        let key = DayKey.string(from: Date())
        return wellbeing.first { $0.dayKey == key }
    }

    private var recentEntries: [WellbeingEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return wellbeing.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    private var recentSamples: [WellbeingSample] {
        recentEntries.map { WellbeingSample(energy: $0.energy, stress: $0.stress, sleepHours: $0.sleepHours, exerciseMinutes: $0.exerciseMinutes) }
    }

    private var weeklyWorkHours: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let minutes = timeEntries.filter { $0.startedAt >= weekAgo }.reduce(0) { $0 + $1.minutes }
        return Double(minutes) / 60.0
    }

    // MARK: - Bindings (lazily create today's entry)

    private func ensureTodayEntry() -> WellbeingEntry {
        if let e = todayEntry { return e }
        let e = WellbeingEntry(date: Date())
        modelContext.insert(e)
        return e
    }

    private var energyBinding: Binding<Double> {
        Binding(get: { Double(todayEntry?.energy ?? 3) },
                set: { ensureTodayEntry().energy = Int($0); try? modelContext.save() })
    }
    private var stressBinding: Binding<Double> {
        Binding(get: { Double(todayEntry?.stress ?? 3) },
                set: { ensureTodayEntry().stress = Int($0); try? modelContext.save() })
    }
    private var sleepBinding: Binding<Double> {
        Binding(get: { todayEntry?.sleepHours ?? 7.5 },
                set: { ensureTodayEntry().sleepHours = $0; try? modelContext.save() })
    }
    private var exerciseBinding: Binding<Double> {
        Binding(get: { Double(todayEntry?.exerciseMinutes ?? 0) },
                set: { ensureTodayEntry().exerciseMinutes = Int($0); try? modelContext.save() })
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }

    private func gradeTint(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

struct AddHabitSheet: View {
    let nextIndex: Int
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "checkmark.seal"

    private let icons = ["checkmark.seal", "figure.run", "brain.head.profile", "bed.double", "book", "drop", "leaf", "dumbbell"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add habit").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Deep work, workout, lights out by 11…", text: $name).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Icon").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(icons, id: \.self) { symbol in
                        Button { icon = symbol } label: {
                            Image(systemName: symbol)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 8).fill(icon == symbol ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08)))
                                .foregroundStyle(icon == symbol ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") {
                    let habit = Habit(name: name, systemImage: icon, sortIndex: nextIndex)
                    modelContext.insert(habit)
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
