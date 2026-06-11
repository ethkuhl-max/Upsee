import Foundation
import SwiftData
import SwiftUI

/// A free-text note attached to any entity by string tag (same pattern as `TimeEntry`)
/// so entity deletes don't drop history. The kind drives display and the activity feed.
@Model
final class JournalEntry {
    var createdAt: Date
    var entityKind: String
    var entityLabel: String
    var body: String
    var kindRaw: String
    var pinned: Bool

    var kind: JournalEntryKind {
        get { JournalEntryKind(rawValue: kindRaw) ?? .observation }
        set { kindRaw = newValue.rawValue }
    }

    init(
        entityKind: String,
        entityLabel: String,
        body: String,
        kind: JournalEntryKind = .observation,
        pinned: Bool = false
    ) {
        self.createdAt = Date()
        self.entityKind = entityKind
        self.entityLabel = entityLabel
        self.body = body
        self.kindRaw = kind.rawValue
        self.pinned = pinned
    }
}

enum JournalEntryKind: String, Codable, CaseIterable {
    case observation
    case blocker
    case win
    case question
    case idea

    var displayName: String {
        switch self {
        case .observation: return "Observation"
        case .blocker: return "Blocker"
        case .win: return "Win"
        case .question: return "Question"
        case .idea: return "Idea"
        }
    }

    var systemImage: String {
        switch self {
        case .observation: return "eye"
        case .blocker: return "exclamationmark.octagon"
        case .win: return "trophy"
        case .question: return "questionmark.circle"
        case .idea: return "lightbulb"
        }
    }

    var tint: Color {
        switch self {
        case .observation: return .secondary
        case .blocker: return .red
        case .win: return .green
        case .question: return .blue
        case .idea: return .yellow
        }
    }
}
