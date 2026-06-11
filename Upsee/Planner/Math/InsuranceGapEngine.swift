import Foundation

struct InsuranceGapLine: Identifiable {
    let id = UUID()
    let kind: InsuranceKind
    let need: Decimal
    let current: Decimal
    let gap: Decimal              // need - current; positive = underinsured
    let status: GapStatus
    let rationale: String
}

enum GapStatus {
    case adequate
    case under
    case over
    case notApplicable

    var displayName: String {
        switch self {
        case .adequate: return "Adequate"
        case .under: return "Under-insured"
        case .over: return "Over-insured"
        case .notApplicable: return "N/A"
        }
    }
}

struct InsuranceGapSummary {
    let lines: [InsuranceGapLine]
    let totalMonthlyPremium: Decimal
    let underInsured: [InsuranceGapLine]
}

/// Standard CFP gap heuristics. Each line is a per-kind comparison: current
/// coverage vs need. The methods are crude but defensible — the value is
/// surfacing the question, not nailing the number.
enum InsuranceGapEngine {
    /// `annualIncome` for life/disability need calc.
    /// `debt`, `mortgageBalance`, `yearsOfIncomeReplacement` for DIME life-need.
    /// `netWorth` for umbrella heuristic ($1M per $1M of net worth).
    /// `monthlyExpenses` for disability income replacement.
    static func summarize(
        policies: [InsurancePolicy],
        annualIncome: Decimal,
        netWorth: Decimal,
        monthlyExpenses: Decimal,
        debt: Decimal = 0,
        mortgageBalance: Decimal = 0,
        yearsOfIncomeReplacement: Int = 10
    ) -> InsuranceGapSummary {
        var lines: [InsuranceGapLine] = []

        // Life — 10× income heuristic OR DIME (the higher of the two when debt/mortgage > 0).
        let tenX = annualIncome * 10
        let dime = debt + (annualIncome * Decimal(yearsOfIncomeReplacement)) + mortgageBalance
        let lifeNeed = max(tenX, dime)
        let lifeCurrent = policies.filter { $0.kind.isLife }.reduce(Decimal(0)) { $0 + $1.coverageAmount }
        lines.append(.init(
            kind: .termLife,
            need: lifeNeed,
            current: lifeCurrent,
            gap: max(0, lifeNeed - lifeCurrent),
            status: status(need: lifeNeed, current: lifeCurrent),
            rationale: "Higher of 10× income or DIME (Debt + Income×\(yearsOfIncomeReplacement)yrs + Mortgage)"
        ))

        // Disability — 60% income replacement target.
        let disabilityNeed = (annualIncome * Decimal(0.6)) / 12   // monthly benefit need
        let disabilityCurrent = policies.filter { $0.kind == .disability }.reduce(Decimal(0)) { $0 + $1.coverageAmount }
        lines.append(.init(
            kind: .disability,
            need: disabilityNeed,
            current: disabilityCurrent,
            gap: max(0, disabilityNeed - disabilityCurrent),
            status: status(need: disabilityNeed, current: disabilityCurrent),
            rationale: "60% of monthly income replacement"
        ))

        // Umbrella — $1M coverage per $1M of net worth.
        let umbrellaNeed = max(Decimal(1_000_000), netWorth)
        let umbrellaCurrent = policies.filter { $0.kind == .umbrella }.reduce(Decimal(0)) { $0 + $1.coverageAmount }
        lines.append(.init(
            kind: .umbrella,
            need: umbrellaNeed,
            current: umbrellaCurrent,
            gap: max(0, umbrellaNeed - umbrellaCurrent),
            status: status(need: umbrellaNeed, current: umbrellaCurrent),
            rationale: "≥ $1M per $1M of net worth"
        ))

        // Property — at least one auto + homeowners/renters.
        let hasHomeOrRenter = policies.contains { $0.kind == .homeowners || $0.kind == .renters }
        let hasAuto = policies.contains { $0.kind == .auto }
        if !hasHomeOrRenter {
            lines.append(.init(
                kind: .renters,
                need: 0, current: 0, gap: 0,
                status: .under,
                rationale: "No homeowners or renters policy on file"
            ))
        }
        if !hasAuto {
            lines.append(.init(
                kind: .auto,
                need: 0, current: 0, gap: 0,
                status: .under,
                rationale: "No auto policy on file"
            ))
        }

        let totalPremium = policies.reduce(Decimal(0)) { $0 + $1.monthlyPremium }
        let under = lines.filter { $0.status == .under }

        return InsuranceGapSummary(lines: lines, totalMonthlyPremium: totalPremium, underInsured: under)
    }

    private static func status(need: Decimal, current: Decimal) -> GapStatus {
        if need <= 0 { return .notApplicable }
        if current >= need { return .adequate }
        if current >= need * Decimal(0.8) { return .under }    // small gap still flagged
        return .under
    }
}
