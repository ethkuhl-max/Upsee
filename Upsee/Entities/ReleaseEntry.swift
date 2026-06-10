import Foundation
import SwiftData

@Model
final class ReleaseEntry {
    var version: String
    var releasedAt: Date
    var summary: String
    var highlights: String
    var notes: String
    var createdAt: Date

    var app: AppEntity?

    init(
        version: String,
        releasedAt: Date = Date(),
        summary: String = "",
        highlights: String = "",
        notes: String = ""
    ) {
        self.version = version
        self.releasedAt = releasedAt
        self.summary = summary
        self.highlights = highlights
        self.notes = notes
        self.createdAt = Date()
    }

    /// Highlights stored as newline-separated; split for display.
    var highlightLines: [String] {
        highlights
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
