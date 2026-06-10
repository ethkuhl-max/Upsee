import Foundation
import SwiftData

/// A logged interval of attention against a specific entity. Entity is tagged by
/// string (`entityKind` + `entityLabel`) rather than a hard SwiftData relationship
/// so deleting an entity doesn't drop its time history — historical attribution
/// for "Tmpo (deleted)" is more useful than silent loss.
@Model
final class TimeEntry {
    var startedAt: Date
    var minutes: Int
    var note: String
    /// One of: "app", "job", "deal", "personal", "other"
    var entityKind: String
    /// Display name at time of logging (e.g., "Tmpo").
    var entityLabel: String
    var createdAt: Date

    init(
        startedAt: Date,
        minutes: Int,
        note: String = "",
        entityKind: String,
        entityLabel: String
    ) {
        self.startedAt = startedAt
        self.minutes = max(0, minutes)
        self.note = note
        self.entityKind = entityKind
        self.entityLabel = entityLabel
        self.createdAt = Date()
    }

    var hours: Double { Double(minutes) / 60.0 }

    var endsAt: Date {
        startedAt.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
