import Foundation
import FoundationModels

/// What the LLM returns from a weekly-briefing call. Stays narrow on purpose —
/// the structure is what makes the result actionable.
@Generable
struct BriefingOutput {
    @Guide(description: "One short paragraph summarizing portfolio state in Underight voice. Specific numbers, no hedging.")
    let overview: String

    @Guide(description: "Two to five specific things drifting off plan. Each one line, concrete, cites a number or fact from the portfolio state.")
    let driftAlerts: [String]

    @Guide(description: "Two to three concrete things deserving focus this week. Specific to the portfolio, not generic advice.")
    let focusRecommendations: [String]

    @Guide(description: "Optional one-line observation the user might not have noticed — a pattern across entities. Null if nothing surfaces.")
    let surprise: String?
}

enum BriefingPrompts {
    static func weekly(context: String) -> String {
        """
        Generate a Monday-morning briefing for a single-operator holdco. Look at the state below \
        and tell the operator what's actually happening, what's drifting, and what deserves \
        focus this week.

        Stay in Underight voice — skeptical, specific, pattern-recognizing. Cite specific numbers \
        from the state. No generic warnings. No hedging. The reader is busy.

        PORTFOLIO STATE
        ---
        \(context)
        ---
        """
    }
}

struct BriefingGenerator {
    let client: FoundationModelsClient

    init(client: FoundationModelsClient = FoundationModelsClient()) {
        self.client = client
    }

    func generate(
        apps: [AppEntity],
        jobs: [JobEntity],
        deals: [DealEntity],
        personal: PersonalEntity?,
        timeEntries: [TimeEntry] = []
    ) async throws -> (output: BriefingOutput, context: String) {
        let context = formatContext(
            apps: apps,
            jobs: jobs,
            deals: deals,
            personal: personal,
            timeEntries: timeEntries
        )
        let output: BriefingOutput = try await client.generate(
            systemInstructions: VoiceGuide.systemPrompt,
            prompt: BriefingPrompts.weekly(context: context)
        )
        return (output, context)
    }

    func formatContext(
        apps: [AppEntity],
        jobs: [JobEntity],
        deals: [DealEntity],
        personal: PersonalEntity?,
        timeEntries: [TimeEntry]
    ) -> String {
        var lines: [String] = []
        let now = Date()

        if !apps.isEmpty {
            lines.append("APPS:")
            for app in apps {
                var parts = ["• \(app.name) [\(app.status.displayName)]"]
                if app.monthlyRevenue > 0 {
                    parts.append("MRR \(formatCurrency(app.monthlyRevenue))")
                }
                if app.activeUsers > 0 {
                    parts.append("\(app.activeUsers) users")
                }
                if let shipped = app.lastShippedAt {
                    let days = Calendar.current.dateComponents([.day], from: shipped, to: now).day ?? 0
                    parts.append("last shipped \(days)d ago")
                }
                if app.inFlightCount > 0 {
                    parts.append("\(app.inFlightCount) in flight")
                }
                if let nextV = app.nextTargetVersion {
                    parts.append("next: v\(nextV)")
                }
                if !app.summary.isEmpty {
                    parts.append("\"\(app.summary)\"")
                }
                if !app.marketingNote.isEmpty {
                    parts.append("marketing: \"\(app.marketingNote)\"")
                }
                lines.append(parts.joined(separator: " | "))

                let activeGoals = app.goals.filter { $0.status == .active }
                for goal in activeGoals.prefix(3) {
                    let progress = goal.quantifiableSummary ?? "no quantified target"
                    let date = goal.targetDate.map { " by \(formatDate($0))" } ?? ""
                    lines.append("    goal: \(goal.title) — \(progress)\(date)")
                }
            }
        }

        if !jobs.isEmpty {
            lines.append("")
            lines.append("JOBS:")
            for job in jobs {
                var parts = ["• \(job.title) at \(job.employer) [\(job.status.displayName)]"]
                if job.monthlyCompensation > 0 {
                    parts.append("\(formatCurrency(job.monthlyCompensation))/mo")
                }
                parts.append("\(job.hoursPerWeek)h/wk")
                if let start = job.startDate {
                    let days = Calendar.current.dateComponents([.day], from: now, to: start).day ?? 0
                    if days > 0 { parts.append("starts in \(days)d") }
                }
                lines.append(parts.joined(separator: " | "))
            }
        }

        if !deals.isEmpty {
            lines.append("")
            lines.append("DEALS:")
            for deal in deals {
                var parts = ["• \(deal.businessName) [\(deal.status.displayName)]"]
                if deal.askingPrice > 0 {
                    parts.append("asking \(formatCurrency(deal.askingPrice))")
                }
                if !deal.lastVerdictLabel.isEmpty {
                    parts.append("verdict: \(deal.lastVerdictLabel)")
                }
                if !deal.lastVerdictHeadline.isEmpty {
                    parts.append("\"\(deal.lastVerdictHeadline)\"")
                }
                lines.append(parts.joined(separator: " | "))
            }
        }

        if let p = personal {
            lines.append("")
            lines.append("PERSONAL:")
            lines.append("• Income \(formatCurrency(p.monthlyIncome))/mo | Expenses \(formatCurrency(p.monthlyExpenses))/mo | Savings \(formatCurrency(p.currentSavings))")
            if p.monthlyBurn > 0 {
                let runway = p.runwayMonths.isInfinite ? "infinite" : String(format: "%.1f mo", p.runwayMonths)
                lines.append("• Burn rate \(formatCurrency(p.monthlyBurn))/mo — runway: \(runway)")
            }
            if !p.note.isEmpty {
                lines.append("• Note: \"\(p.note)\"")
            }
        }

        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let weekEntries = timeEntries.filter { $0.startedAt >= weekAgo }
        if !weekEntries.isEmpty {
            lines.append("")
            lines.append("TIME (last 7 days):")
            let grouped = Dictionary(grouping: weekEntries) { "\($0.entityKind)/\($0.entityLabel)" }
            let sorted = grouped.sorted { lhs, rhs in
                let l = lhs.value.reduce(0) { $0 + $1.minutes }
                let r = rhs.value.reduce(0) { $0 + $1.minutes }
                return l > r
            }
            for (key, entries) in sorted {
                let minutes = entries.reduce(0) { $0 + $1.minutes }
                let h = minutes / 60
                let m = minutes % 60
                let label = key.split(separator: "/").last.map(String.init) ?? key
                lines.append("• \(label): \(h)h \(m)m")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatCurrency(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencyCode = "USD"
        return f.string(from: NSDecimalNumber(decimal: d)) ?? "$0"
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }
}
