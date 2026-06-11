import Foundation
import SwiftUI

/// A single point on the cross-entity activity timeline. Computed at view time
/// from existing entities — no separate persistence layer to keep in sync.
struct ActivityEvent: Identifiable, Hashable {
    let id: String
    let date: Date
    let kind: ActivityEventKind
    let entityKind: ActivityEntityRef
    let entityLabel: String?
    let title: String
    let detail: String?
}

enum ActivityEventKind: String, CaseIterable, Hashable {
    case release
    case roadmap
    case decision
    case journal
    case netWorthSnapshot
    case taxPayment
    case briefing
    case weeklyCommitmentSet
    case weeklyCommitmentClosed
    case reviewNeeded
    case dealAnalyzed
    case dataImport

    var displayName: String {
        switch self {
        case .release: return "Release"
        case .roadmap: return "Roadmap"
        case .decision: return "Decision"
        case .journal: return "Journal"
        case .netWorthSnapshot: return "Net Worth"
        case .taxPayment: return "Tax"
        case .briefing: return "Briefing"
        case .weeklyCommitmentSet: return "Commitment Set"
        case .weeklyCommitmentClosed: return "Commitment Closed"
        case .reviewNeeded: return "Review Needed"
        case .dealAnalyzed: return "Deal Analyzed"
        case .dataImport: return "Import"
        }
    }

    var systemImage: String {
        switch self {
        case .release: return "shippingbox.fill"
        case .roadmap: return "list.bullet.rectangle"
        case .decision: return "scale.3d"
        case .journal: return "text.book.closed"
        case .netWorthSnapshot: return "camera.aperture"
        case .taxPayment: return "dollarsign.circle"
        case .briefing: return "sparkles.rectangle.stack"
        case .weeklyCommitmentSet: return "flag"
        case .weeklyCommitmentClosed: return "flag.checkered"
        case .reviewNeeded: return "questionmark.diamond"
        case .dealAnalyzed: return "doc.text.magnifyingglass"
        case .dataImport: return "tray.and.arrow.down.fill"
        }
    }

    var tint: Color {
        switch self {
        case .release: return .purple
        case .roadmap: return .blue
        case .decision: return .indigo
        case .journal: return .secondary
        case .netWorthSnapshot: return .green
        case .taxPayment: return .orange
        case .briefing: return .pink
        case .weeklyCommitmentSet: return .blue
        case .weeklyCommitmentClosed: return .green
        case .reviewNeeded: return .orange
        case .dealAnalyzed: return .teal
        case .dataImport: return .cyan
        }
    }
}

enum ActivityEntityRef: String, Hashable {
    case app, job, deal, personal, portfolio, none
}
