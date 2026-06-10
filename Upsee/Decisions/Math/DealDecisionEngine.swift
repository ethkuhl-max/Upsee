import Foundation

enum DealVerdict: String, CaseIterable {
    case proceed
    case proceedWithDD
    case walk
    case watching

    var displayName: String {
        switch self {
        case .proceed: return "Proceed"
        case .proceedWithDD: return "Proceed → DD"
        case .walk: return "Walk"
        case .watching: return "Watching"
        }
    }
}

struct DealDecisionRecommendation: Identifiable {
    let id = UUID()
    let businessName: String
    let verdict: DealVerdict
    /// Headline from the analysis, if any.
    let analysisHeadline: String?
    /// "PROCEED" / "WALK" / etc. from the analysis verdict.
    let analysisDisposition: String?
    let signals: [AppDecisionSignal]
    let reasoning: String
}

enum DealDecisionEngine {
    static func recommend(deal: DealEntity) -> DealDecisionRecommendation {
        var signals: [AppDecisionSignal] = []

        let askingPriceDouble = NSDecimalNumber(decimal: deal.askingPrice).doubleValue
        let sdeDouble = NSDecimalNumber(decimal: deal.reportedSDE).doubleValue
        let multiple: Double = sdeDouble > 0 ? askingPriceDouble / sdeDouble : 0

        if multiple > 0 {
            if multiple <= 2.5 {
                signals.append(.init(label: "Multiple", detail: String(format: "%.1fx SDE — cheap", multiple), polarity: 1))
            } else if multiple <= 4.0 {
                signals.append(.init(label: "Multiple", detail: String(format: "%.1fx SDE — fair", multiple), polarity: 0))
            } else {
                signals.append(.init(label: "Multiple", detail: String(format: "%.1fx SDE — rich", multiple), polarity: -1))
            }
        }

        // Pull the analysis verdict if present.
        let analysis = deal.savedAnalysis
        let analysisDispoString: String? = {
            guard let analysis else { return nil }
            return analysis.verdict.disposition.rawValue
        }()

        if let dispo = analysisDispoString {
            let lower = dispo.lowercased()
            if lower.contains("proceed") || lower.contains("buy") {
                signals.append(.init(label: "Analysis", detail: dispo, polarity: 1))
            } else if lower.contains("walk") || lower.contains("pass") {
                signals.append(.init(label: "Analysis", detail: dispo, polarity: -1))
            } else {
                signals.append(.init(label: "Analysis", detail: dispo, polarity: 0))
            }
        } else {
            signals.append(.init(label: "Analysis", detail: "Not yet analyzed", polarity: -1))
        }

        // Pipeline status weight.
        switch deal.status {
        case .loi, .dueDiligence:
            signals.append(.init(label: "Stage", detail: deal.status.displayName, polarity: 1))
        case .passed, .dead:
            signals.append(.init(label: "Stage", detail: deal.status.displayName, polarity: -1))
        case .watching, .closed:
            signals.append(.init(label: "Stage", detail: deal.status.displayName, polarity: 0))
        }

        // Stale analysis penalty.
        if let lastAnalyzed = deal.lastAnalyzedAt {
            let daysOld = Calendar.current.dateComponents([.day], from: lastAnalyzed, to: Date()).day ?? 0
            if daysOld > 60 {
                signals.append(.init(label: "Freshness", detail: "Analysis \(daysOld)d old", polarity: -1))
            }
        }

        let polarity = signals.reduce(0) { $0 + $1.polarity }
        let verdict: DealVerdict = {
            if analysisDispoString == nil { return .watching }
            let lower = (analysisDispoString ?? "").lowercased()
            if lower.contains("walk") || lower.contains("pass") || polarity <= -2 { return .walk }
            if polarity >= 2 { return .proceed }
            if polarity >= 0 { return .proceedWithDD }
            return .walk
        }()

        let reasoning: String = {
            switch verdict {
            case .proceed:
                return "\(deal.businessName): the math, the multiple, and the analysis all point the same way. Move to LOI."
            case .proceedWithDD:
                return "\(deal.businessName): worth pursuing, but the analysis raises material questions. Open a DD checklist before you commit."
            case .walk:
                return "\(deal.businessName): the signals don't support a buy. Either reprice the offer materially or move on."
            case .watching:
                return "\(deal.businessName) isn't analyzed yet — run it through Underight before deciding."
            }
        }()

        return DealDecisionRecommendation(
            businessName: deal.businessName,
            verdict: verdict,
            analysisHeadline: deal.lastVerdictHeadline.isEmpty ? nil : deal.lastVerdictHeadline,
            analysisDisposition: analysisDispoString,
            signals: signals,
            reasoning: reasoning
        )
    }
}
