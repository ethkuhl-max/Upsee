import Foundation

enum AppVerdict: String, CaseIterable {
    case doubleDown   // strong ROI, momentum, ship it harder
    case grow         // promising — invest more attention
    case hold         // tread water — neither kill nor grow
    case kill         // sunset candidate
    case rescue       // negative trend but salvageable

    var displayName: String {
        switch self {
        case .doubleDown: return "Double Down"
        case .grow: return "Grow"
        case .hold: return "Hold"
        case .kill: return "Kill"
        case .rescue: return "Rescue"
        }
    }
}

struct AppDecisionSignal: Identifiable {
    let id = UUID()
    let label: String
    let detail: String
    /// 1 = positive, 0 = neutral, -1 = negative
    let polarity: Int
}

struct AppDecisionRecommendation: Identifiable {
    let id = UUID()
    let appName: String
    let verdict: AppVerdict
    /// Revenue per logged hour over the lookback window. 0 if no hours logged.
    let revenuePerHour: Decimal
    /// Hours logged in the lookback window.
    let hoursLogged: Double
    /// Revenue this month (proxied by monthlyRevenue).
    let monthlyRevenue: Decimal
    let daysSinceLastShipped: Int?
    let signals: [AppDecisionSignal]
    let reasoning: String
}

enum AppDecisionEngine {
    /// Per-app verdict from monthly revenue, hours logged in the last `lookbackDays`,
    /// and ship cadence. Deliberately mechanical — the LLM voice lives elsewhere.
    static func recommend(
        app: AppEntity,
        timeEntries: [TimeEntry],
        lookbackDays: Int = 30,
        now: Date = Date()
    ) -> AppDecisionRecommendation {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        let appHours = timeEntries
            .filter { $0.entityKind == "app" && $0.entityLabel == app.name && $0.startedAt >= cutoff }
            .reduce(0.0) { $0 + $1.hours }

        let revenue = app.monthlyRevenue
        let revenueDouble = NSDecimalNumber(decimal: revenue).doubleValue
        let revenuePerHour: Decimal = appHours > 0 ? Decimal(revenueDouble / appHours) : 0

        let daysSinceShipped: Int? = app.lastShippedAt.map {
            Calendar.current.dateComponents([.day], from: $0, to: now).day ?? 0
        }

        var signals: [AppDecisionSignal] = []

        // Revenue signal
        if revenueDouble >= 1_000 {
            signals.append(.init(label: "Revenue", detail: "$\(Int(revenueDouble))/mo — meaningful", polarity: 1))
        } else if revenueDouble > 0 {
            signals.append(.init(label: "Revenue", detail: "$\(Int(revenueDouble))/mo — small but real", polarity: 0))
        } else {
            signals.append(.init(label: "Revenue", detail: "$0/mo", polarity: -1))
        }

        // Time-to-revenue signal
        if appHours > 0 {
            let perHour = Int(revenueDouble / appHours)
            if perHour >= 50 {
                signals.append(.init(label: "Time ROI", detail: "$\(perHour)/hr — strong", polarity: 1))
            } else if perHour >= 10 {
                signals.append(.init(label: "Time ROI", detail: "$\(perHour)/hr — acceptable", polarity: 0))
            } else {
                signals.append(.init(label: "Time ROI", detail: "$\(perHour)/hr — thin", polarity: -1))
            }
        } else if revenueDouble > 0 {
            signals.append(.init(label: "Time ROI", detail: "Revenue with 0 hours logged — passive", polarity: 1))
        } else {
            signals.append(.init(label: "Attention", detail: "0 hours and $0 — silent", polarity: -1))
        }

        // Ship cadence signal
        if let days = daysSinceShipped {
            if days <= 30 {
                signals.append(.init(label: "Cadence", detail: "Shipped \(days)d ago", polarity: 1))
            } else if days <= 90 {
                signals.append(.init(label: "Cadence", detail: "Last ship \(days)d ago", polarity: 0))
            } else {
                signals.append(.init(label: "Cadence", detail: "Stale — \(days)d since ship", polarity: -1))
            }
        } else {
            signals.append(.init(label: "Cadence", detail: "Never shipped", polarity: -1))
        }

        // Status override signal
        switch app.status {
        case .stalled:
            signals.append(.init(label: "Status", detail: "Marked stalled", polarity: -1))
        case .sunset:
            signals.append(.init(label: "Status", detail: "Marked sunset", polarity: -1))
        case .active:
            signals.append(.init(label: "Status", detail: "Active", polarity: 1))
        case .maintenance:
            signals.append(.init(label: "Status", detail: "Maintenance mode", polarity: 0))
        case .shipped:
            signals.append(.init(label: "Status", detail: "Shipped", polarity: 1))
        }

        let polarity = signals.reduce(0) { $0 + $1.polarity }
        let verdict: AppVerdict = pickVerdict(
            polarity: polarity,
            hours: appHours,
            revenue: revenueDouble,
            status: app.status,
            daysSinceShipped: daysSinceShipped
        )

        let reasoning = renderReasoning(
            verdict: verdict,
            appName: app.name,
            revenue: revenueDouble,
            hours: appHours,
            daysSinceShipped: daysSinceShipped
        )

        return AppDecisionRecommendation(
            appName: app.name,
            verdict: verdict,
            revenuePerHour: revenuePerHour,
            hoursLogged: appHours,
            monthlyRevenue: revenue,
            daysSinceLastShipped: daysSinceShipped,
            signals: signals,
            reasoning: reasoning
        )
    }

    private static func pickVerdict(
        polarity: Int,
        hours: Double,
        revenue: Double,
        status: AppStatus,
        daysSinceShipped: Int?
    ) -> AppVerdict {
        if status == .sunset { return .kill }
        // High revenue + good polarity → double down.
        if revenue >= 1_000 && polarity >= 3 { return .doubleDown }
        // Has revenue and positive signals overall → grow.
        if revenue > 0 && polarity >= 1 { return .grow }
        // Heavy time, no revenue, very stale → kill candidate.
        if revenue == 0 && hours >= 20 && (daysSinceShipped ?? 999) > 60 { return .kill }
        // Some time invested, no revenue, but recent activity → rescue.
        if revenue == 0 && hours > 0 && (daysSinceShipped ?? 999) <= 60 { return .rescue }
        // Zero hours and zero revenue → kill candidate (silent).
        if revenue == 0 && hours == 0 && (daysSinceShipped ?? 999) > 90 { return .kill }
        if polarity <= -2 { return .kill }
        return .hold
    }

    private static func renderReasoning(
        verdict: AppVerdict,
        appName: String,
        revenue: Double,
        hours: Double,
        daysSinceShipped: Int?
    ) -> String {
        let rev = Int(revenue)
        let hrs = String(format: "%.1f", hours)
        let shipNote: String = {
            guard let d = daysSinceShipped else { return "never shipped" }
            return "last ship \(d)d ago"
        }()

        switch verdict {
        case .doubleDown:
            return "\(appName) is producing $\(rev)/mo on \(hrs)h of attention (\(shipNote)). This is your strongest signal — protect this time block."
        case .grow:
            return "\(appName) has revenue and momentum. Adding focused hours here has higher expected return than the alternatives."
        case .hold:
            return "\(appName) is treading water on \(hrs)h. Don't kill it, but don't add more — find a forcing function or revisit in 30 days."
        case .kill:
            return "\(appName) shows $\(rev) revenue and \(shipNote). Continuing to log hours here is donating time. Sunset or freeze."
        case .rescue:
            return "\(appName) has activity but no revenue yet. One of: pricing, distribution, or the wedge isn't sharp enough. Pick one, give it 30 days, then re-decide."
        }
    }
}
