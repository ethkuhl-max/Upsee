import XCTest
@testable import Upsee

final class ActivityEventBuilderTests: XCTestCase {
    func testEmptySourcesProducesEmpty() {
        let result = ActivityEventBuilder.build(.init())
        XCTAssertTrue(result.isEmpty)
    }

    func testReviewNeededProjectedForStaleDecision() {
        let old = Calendar.current.date(byAdding: .day, value: -45, to: Date())!
        let decision = DecisionEntity(kind: .app, targetLabel: "Tmpo", recommendation: "Grow", userChoice: "Hold")
        decision.createdAt = old
        var sources = ActivityEventBuilder.Sources()
        sources.decisions = [decision]
        let events = ActivityEventBuilder.build(sources)
        XCTAssertTrue(events.contains { $0.kind == .reviewNeeded })
    }

    func testReviewNotProjectedForFreshDecision() {
        let decision = DecisionEntity(kind: .app, targetLabel: "Tmpo", recommendation: "Grow", userChoice: "Hold")
        var sources = ActivityEventBuilder.Sources()
        sources.decisions = [decision]
        let events = ActivityEventBuilder.build(sources)
        XCTAssertFalse(events.contains { $0.kind == .reviewNeeded })
    }

    func testReviewNotProjectedWhenOutcomeExists() {
        let old = Calendar.current.date(byAdding: .day, value: -45, to: Date())!
        let decision = DecisionEntity(kind: .app, targetLabel: "Tmpo", recommendation: "Grow", userChoice: "Hold")
        decision.createdAt = old
        decision.outcome = "Worked out"
        var sources = ActivityEventBuilder.Sources()
        sources.decisions = [decision]
        let events = ActivityEventBuilder.build(sources)
        XCTAssertFalse(events.contains { $0.kind == .reviewNeeded })
    }

    func testEventsAreSortedNewestFirst() {
        let oldDecision = DecisionEntity(kind: .app, targetLabel: "Old", recommendation: "Hold", userChoice: "Hold")
        oldDecision.createdAt = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let newDecision = DecisionEntity(kind: .app, targetLabel: "New", recommendation: "Grow", userChoice: "Grow")
        var sources = ActivityEventBuilder.Sources()
        sources.decisions = [oldDecision, newDecision]
        let events = ActivityEventBuilder.build(sources)
        let decisionEvents = events.filter { $0.kind == .decision }
        XCTAssertEqual(decisionEvents.first?.entityLabel, "New")
        XCTAssertEqual(decisionEvents.last?.entityLabel, "Old")
    }

    func testJournalEntryProducesEvent() {
        let entry = JournalEntry(entityKind: "app", entityLabel: "Tmpo", body: "Shipped today!", kind: .win)
        var sources = ActivityEventBuilder.Sources()
        sources.journal = [entry]
        let events = ActivityEventBuilder.build(sources)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .journal)
        XCTAssertEqual(events.first?.entityLabel, "Tmpo")
    }

    func testWeeklyCommitmentClosedProducesTwoEvents() {
        let commitment = WeeklyCommitment(
            weekStart: WeekStart.of(Date()),
            entityKind: "app",
            entityLabel: "Tmpo",
            commitment: "Ship onboarding",
            hoursTarget: 8,
            status: .hit
        )
        commitment.outcome = "Done"
        var sources = ActivityEventBuilder.Sources()
        sources.commitments = [commitment]
        let events = ActivityEventBuilder.build(sources)
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.contains { $0.kind == .weeklyCommitmentSet })
        XCTAssertTrue(events.contains { $0.kind == .weeklyCommitmentClosed })
    }

    func testLimitCapsResult() {
        var sources = ActivityEventBuilder.Sources()
        sources.journal = (1...50).map { _ in
            JournalEntry(entityKind: "app", entityLabel: "X", body: "note")
        }
        let events = ActivityEventBuilder.build(sources, limit: 10)
        XCTAssertEqual(events.count, 10)
    }
}
