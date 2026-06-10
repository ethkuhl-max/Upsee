import Foundation

enum JobVerdict: String, CaseIterable {
    case takeIt
    case negotiate
    case decline
    case continueSearch

    var displayName: String {
        switch self {
        case .takeIt: return "Take It"
        case .negotiate: return "Negotiate"
        case .decline: return "Decline"
        case .continueSearch: return "Keep Searching"
        }
    }
}

struct JobDecisionRecommendation: Identifiable {
    let id = UUID()
    let jobTitle: String
    let employer: String
    let verdict: JobVerdict
    /// Monthly comp ÷ hours per week — a crude $/hr proxy.
    let effectiveHourlyRate: Decimal
    /// Hours per week that would shift away from apps & deals.
    let opportunityCost: Int
    /// Runway extension in months at the personal entity's expense rate.
    let runwayMonthsAdded: Double
    let signals: [AppDecisionSignal]
    let reasoning: String
}

enum JobDecisionEngine {
    static func recommend(
        job: JobEntity,
        personal: PersonalEntity?,
        appsRevenue: Decimal
    ) -> JobDecisionRecommendation {
        let monthlyComp = NSDecimalNumber(decimal: job.monthlyCompensation).doubleValue
        let weeklyHours = max(1, job.hoursPerWeek)
        let monthlyHours = Double(weeklyHours) * 4.33
        let hourly: Double = monthlyHours > 0 ? monthlyComp / monthlyHours : 0

        let monthlyExpenses = NSDecimalNumber(decimal: personal?.monthlyExpenses ?? 0).doubleValue
        let appsMonthly = NSDecimalNumber(decimal: appsRevenue).doubleValue
        let netIncome = monthlyComp + appsMonthly - monthlyExpenses
        let runwayAdded: Double = monthlyExpenses > 0 ? netIncome / monthlyExpenses : 0

        var signals: [AppDecisionSignal] = []

        if hourly >= 100 {
            signals.append(.init(label: "Rate", detail: "$\(Int(hourly))/hr — strong", polarity: 1))
        } else if hourly >= 50 {
            signals.append(.init(label: "Rate", detail: "$\(Int(hourly))/hr — market", polarity: 0))
        } else if hourly > 0 {
            signals.append(.init(label: "Rate", detail: "$\(Int(hourly))/hr — under market", polarity: -1))
        }

        if weeklyHours <= 20 {
            signals.append(.init(label: "Hours", detail: "\(weeklyHours)h/wk — leaves room for apps", polarity: 1))
        } else if weeklyHours <= 40 {
            signals.append(.init(label: "Hours", detail: "\(weeklyHours)h/wk — standard load", polarity: 0))
        } else {
            signals.append(.init(label: "Hours", detail: "\(weeklyHours)h/wk — squeezes apps", polarity: -1))
        }

        if netIncome >= monthlyExpenses {
            signals.append(.init(label: "Coverage", detail: "Net covers \(String(format: "%.1f", runwayAdded))x expenses", polarity: 1))
        } else if netIncome > 0 {
            signals.append(.init(label: "Coverage", detail: "Partial — gap remains", polarity: 0))
        } else {
            signals.append(.init(label: "Coverage", detail: "Net negative after expenses", polarity: -1))
        }

        let polarity = signals.reduce(0) { $0 + $1.polarity }
        let verdict: JobVerdict = {
            if job.status == .ended { return .declineFinal() }
            if polarity >= 2 { return .takeIt }
            if polarity == 1 { return .negotiate }
            if polarity <= -2 { return .decline }
            return .continueSearch
        }()

        let reasoning: String = {
            switch verdict {
            case .takeIt:
                return "\(job.title) at \(job.employer) covers expenses with room to spare and leaves time for apps. Take it unless you have a better-paying offer in motion."
            case .negotiate:
                return "Reasonable but borderline. Negotiate rate or scope before signing — the marginal hour matters here."
            case .decline:
                return "Doesn't pencil out — under-market and squeezes app time. Pass unless runway is the dominant constraint."
            case .continueSearch:
                return "Neither a yes nor a no on the numbers. Keep this one warm and run the search."
            }
        }()

        return JobDecisionRecommendation(
            jobTitle: job.title,
            employer: job.employer,
            verdict: verdict,
            effectiveHourlyRate: Decimal(hourly),
            opportunityCost: weeklyHours,
            runwayMonthsAdded: runwayAdded,
            signals: signals,
            reasoning: reasoning
        )
    }
}

private extension JobVerdict {
    /// Workaround — Swift needs an expression here; this just maps "ended" → decline.
    static func declineFinal() -> JobVerdict { .decline }
}
