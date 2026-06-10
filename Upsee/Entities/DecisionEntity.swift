import Foundation
import SwiftData
import SwiftUI

/// A logged decision — what the system recommended, what you chose, why, and
/// (later) how it played out. The retrospective field is the point: in 6 months
/// you can grade your judgment, not just the recommendation.
@Model
final class DecisionEntity {
    var createdAt: Date
    var kindRaw: String
    /// Display name of the entity at decision time (app name, job title, deal name).
    var targetLabel: String
    /// What the engine suggested ("Hold", "Grow", etc.).
    var recommendation: String
    /// What the user actually picked.
    var userChoice: String
    var rationale: String
    /// Filled in later when the user reviews the call.
    var outcome: String
    var outcomeUpdatedAt: Date?

    var kind: DecisionKind {
        get { DecisionKind(rawValue: kindRaw) ?? .app }
        set { kindRaw = newValue.rawValue }
    }

    init(
        kind: DecisionKind,
        targetLabel: String,
        recommendation: String,
        userChoice: String,
        rationale: String = ""
    ) {
        self.createdAt = Date()
        self.kindRaw = kind.rawValue
        self.targetLabel = targetLabel
        self.recommendation = recommendation
        self.userChoice = userChoice
        self.rationale = rationale
        self.outcome = ""
        self.outcomeUpdatedAt = nil
    }

    var matchedRecommendation: Bool {
        userChoice.lowercased() == recommendation.lowercased()
    }
}

enum DecisionKind: String, Codable, CaseIterable {
    case app, job, deal

    var displayName: String {
        switch self {
        case .app: return "App"
        case .job: return "Job"
        case .deal: return "Deal"
        }
    }

    var tint: Color {
        switch self {
        case .app: return .blue
        case .job: return .green
        case .deal: return .purple
        }
    }

    var systemImage: String {
        switch self {
        case .app: return "app.badge"
        case .job: return "briefcase"
        case .deal: return "doc.text.magnifyingglass"
        }
    }
}
