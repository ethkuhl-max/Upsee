import Foundation

/// Projects the persisted entity world into a flat, sorted activity stream.
/// Pure function over queries — easy to test, no side effects.
enum ActivityEventBuilder {
    struct Sources {
        var apps: [AppEntity] = []
        var releases: [ReleaseEntry] = []
        var roadmap: [RoadmapItem] = []
        var decisions: [DecisionEntity] = []
        var journal: [JournalEntry] = []
        var snapshots: [NetWorthSnapshot] = []
        var taxPayments: [TaxPayment] = []
        var briefings: [BriefingEntity] = []
        var commitments: [WeeklyCommitment] = []
        var deals: [DealEntity] = []
        var now: Date = Date()
        /// Stale-retro threshold (days). Decisions logged before this and still
        /// without an outcome emit a `reviewNeeded` event.
        var retroDays: Int = 30
    }

    static func build(_ s: Sources, limit: Int = 200) -> [ActivityEvent] {
        var events: [ActivityEvent] = []

        for release in s.releases {
            events.append(.init(
                id: "release-\(ObjectIdentifier(release).hashValue)",
                date: release.releasedAt,
                kind: .release,
                entityKind: .app,
                entityLabel: release.app?.name,
                title: "Shipped \(release.version)",
                detail: release.summary.isEmpty ? nil : release.summary
            ))
        }

        // Roadmap status changes: we don't have a change-log, but updatedAt + status
        // is a good enough proxy — "in-progress / shipped / cancelled at X".
        for item in s.roadmap where item.status != .idea && item.status != .planned {
            events.append(.init(
                id: "roadmap-\(ObjectIdentifier(item).hashValue)",
                date: item.updatedAt,
                kind: .roadmap,
                entityKind: .app,
                entityLabel: item.app?.name,
                title: "\(item.title) → \(item.status.displayName)",
                detail: item.targetVersion.map { "Target \($0)" }
            ))
        }

        for decision in s.decisions {
            events.append(.init(
                id: "decision-\(ObjectIdentifier(decision).hashValue)",
                date: decision.createdAt,
                kind: .decision,
                entityKind: ref(for: decision.kind),
                entityLabel: decision.targetLabel,
                title: "Decided: \(decision.userChoice)",
                detail: "Recommended \(decision.recommendation)"
            ))

            // Retro-needed projection.
            let ageDays = Calendar.current.dateComponents([.day], from: decision.createdAt, to: s.now).day ?? 0
            if decision.outcome.isEmpty && ageDays >= s.retroDays {
                events.append(.init(
                    id: "retro-\(ObjectIdentifier(decision).hashValue)",
                    date: s.now,
                    kind: .reviewNeeded,
                    entityKind: ref(for: decision.kind),
                    entityLabel: decision.targetLabel,
                    title: "Grade your call on \(decision.targetLabel)",
                    detail: "\(ageDays)d old — no outcome logged yet"
                ))
            }
        }

        for entry in s.journal {
            events.append(.init(
                id: "journal-\(ObjectIdentifier(entry).hashValue)",
                date: entry.createdAt,
                kind: .journal,
                entityKind: ref(forJournalKind: entry.entityKind),
                entityLabel: entry.entityLabel,
                title: "\(entry.kind.displayName): \(snippet(entry.body, max: 80))",
                detail: entry.body.count > 80 ? entry.body : nil
            ))
        }

        for snap in s.snapshots {
            events.append(.init(
                id: "snap-\(ObjectIdentifier(snap).hashValue)",
                date: snap.date,
                kind: .netWorthSnapshot,
                entityKind: .portfolio,
                entityLabel: nil,
                title: "Net worth snapshot: \(currencyShort(snap.netWorth))",
                detail: nil
            ))
        }

        for payment in s.taxPayments {
            events.append(.init(
                id: "tax-\(ObjectIdentifier(payment).hashValue)",
                date: payment.paidAt,
                kind: .taxPayment,
                entityKind: .personal,
                entityLabel: nil,
                title: "\(payment.kind.displayName) tax Q\(payment.quarterNumber) — \(currencyShort(payment.amount))",
                detail: payment.note.isEmpty ? nil : payment.note
            ))
        }

        for briefing in s.briefings {
            events.append(.init(
                id: "briefing-\(ObjectIdentifier(briefing).hashValue)",
                date: briefing.createdAt,
                kind: .briefing,
                entityKind: .portfolio,
                entityLabel: nil,
                title: "Weekly briefing generated",
                detail: snippet(briefing.overview, max: 140)
            ))
        }

        for commitment in s.commitments {
            events.append(.init(
                id: "commit-set-\(ObjectIdentifier(commitment).hashValue)",
                date: commitment.createdAt,
                kind: .weeklyCommitmentSet,
                entityKind: .app,
                entityLabel: commitment.entityLabel,
                title: "Committed: \(commitment.commitment)",
                detail: commitment.hoursTarget > 0 ? "Target \(commitment.hoursTarget)h" : nil
            ))

            if commitment.status == .hit || commitment.status == .missed || commitment.status == .dropped {
                events.append(.init(
                    id: "commit-close-\(ObjectIdentifier(commitment).hashValue)",
                    date: commitment.updatedAt,
                    kind: .weeklyCommitmentClosed,
                    entityKind: .app,
                    entityLabel: commitment.entityLabel,
                    title: "\(commitment.status.displayName): \(commitment.commitment)",
                    detail: commitment.outcome.isEmpty ? nil : commitment.outcome
                ))
            }
        }

        for deal in s.deals where deal.lastAnalyzedAt != nil {
            events.append(.init(
                id: "deal-\(ObjectIdentifier(deal).hashValue)",
                date: deal.lastAnalyzedAt ?? deal.updatedAt,
                kind: .dealAnalyzed,
                entityKind: .deal,
                entityLabel: deal.businessName,
                title: "Analyzed \(deal.businessName)",
                detail: deal.lastVerdictHeadline.isEmpty ? nil : deal.lastVerdictHeadline
            ))
        }

        // Sort newest first, cap to limit.
        events.sort { $0.date > $1.date }
        if events.count > limit { events.removeLast(events.count - limit) }
        return events
    }

    private static func ref(for kind: DecisionKind) -> ActivityEntityRef {
        switch kind {
        case .app: return .app
        case .job: return .job
        case .deal: return .deal
        }
    }

    private static func ref(forJournalKind kind: String) -> ActivityEntityRef {
        switch kind {
        case "app": return .app
        case "job": return .job
        case "deal": return .deal
        case "personal": return .personal
        default: return .none
        }
    }

    private static func snippet(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }

    private static func currencyShort(_ d: Decimal) -> String {
        let value = NSDecimalNumber(decimal: d).doubleValue
        if abs(value) >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if abs(value) >= 1_000 { return String(format: "$%.1fK", value / 1_000) }
        return "$\(Int(value))"
    }
}
