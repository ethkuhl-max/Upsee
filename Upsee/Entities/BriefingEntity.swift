import Foundation
import SwiftData

@Model
final class BriefingEntity {
    var createdAt: Date
    var overview: String
    /// Newline-separated drift items.
    var driftAlerts: String
    /// Newline-separated focus recommendations.
    var focusRecommendations: String
    var surprise: String?
    /// Raw context snapshot that was sent to the model — useful for transparency / debugging.
    var contextSummary: String

    init(
        createdAt: Date = Date(),
        overview: String,
        driftAlerts: String = "",
        focusRecommendations: String = "",
        surprise: String? = nil,
        contextSummary: String = ""
    ) {
        self.createdAt = createdAt
        self.overview = overview
        self.driftAlerts = driftAlerts
        self.focusRecommendations = focusRecommendations
        self.surprise = surprise
        self.contextSummary = contextSummary
    }

    var driftLines: [String] {
        driftAlerts
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var focusLines: [String] {
        focusRecommendations
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
