import Foundation

struct RiskQuestion: Identifiable {
    let id: Int
    let prompt: String
    let options: [String]   // option index is its weight (0…3)
}

enum RiskBand: String {
    case conservative, moderateConservative, moderate, moderateAggressive, aggressive

    var displayName: String {
        switch self {
        case .conservative: return "Conservative"
        case .moderateConservative: return "Moderately Conservative"
        case .moderate: return "Moderate"
        case .moderateAggressive: return "Moderately Aggressive"
        case .aggressive: return "Aggressive"
        }
    }

    init(score: Int) {
        switch score {
        case ..<20: self = .conservative
        case ..<40: self = .moderateConservative
        case ..<60: self = .moderate
        case ..<80: self = .moderateAggressive
        default: self = .aggressive
        }
    }
}

struct RiskProfile: Equatable {
    let score: Int            // 0…100
    let bandRaw: String
    let equityPct: Int
    let bondPct: Int
    let cashPct: Int

    var band: RiskBand { RiskBand(rawValue: bandRaw) ?? .moderate }
}

/// Scores a risk-tolerance questionnaire and maps it to a target asset allocation.
enum RiskProfileEngine {
    static let questions: [RiskQuestion] = [
        RiskQuestion(id: 0, prompt: "Primary goal for this money", options: [
            "Preserve capital", "Income with some growth", "Balanced growth", "Maximize long-term growth",
        ]),
        RiskQuestion(id: 1, prompt: "Time horizon before withdrawals", options: [
            "Under 3 years", "3–7 years", "7–15 years", "15+ years",
        ]),
        RiskQuestion(id: 2, prompt: "If the portfolio fell 20% in a year, you would", options: [
            "Sell everything", "Sell some", "Hold", "Buy more",
        ]),
        RiskQuestion(id: 3, prompt: "Investment experience", options: [
            "None", "Limited", "Good", "Extensive",
        ]),
        RiskQuestion(id: 4, prompt: "Stability of income / job", options: [
            "Unstable", "Somewhat stable", "Stable", "Very stable",
        ]),
        RiskQuestion(id: 5, prompt: "Which return/risk tradeoff fits best", options: [
            "+4% / −5%", "+7% / −12%", "+10% / −20%", "+13% / −30%",
        ]),
    ]

    static var maxRawScore: Int { questions.count * 3 }

    static func score(answers: [Int]) -> RiskProfile {
        let raw = zip(answers, questions).reduce(0) { sum, pair in
            sum + min(max(pair.0, 0), pair.1.options.count - 1)
        }
        let score = maxRawScore > 0 ? Int((Double(raw) / Double(maxRawScore) * 100).rounded()) : 0
        let alloc = allocation(forScore: score)
        return RiskProfile(score: score, bandRaw: RiskBand(score: score).rawValue,
                           equityPct: alloc.equity, bondPct: alloc.bond, cashPct: alloc.cash)
    }

    /// Target allocation: equity rises with score, cash/bonds fill the remainder.
    static func allocation(forScore score: Int) -> (equity: Int, bond: Int, cash: Int) {
        let equity = min(90, max(20, Int((20 + Double(score) * 0.7).rounded())))
        let rest = 100 - equity
        let cash = min(rest, max(5, Int((Double(rest) * 0.25).rounded())))
        let bond = rest - cash
        return (equity, bond, cash)
    }
}
