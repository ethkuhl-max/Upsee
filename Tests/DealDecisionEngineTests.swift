import XCTest
@testable import Upsee

final class DealDecisionEngineTests: XCTestCase {
    func testWatchingWhenNoAnalysis() {
        let deal = DealEntity(businessName: "Acme", askingPrice: 500_000, reportedSDE: 150_000, status: .watching)
        let rec = DealDecisionEngine.recommend(deal: deal)
        XCTAssertEqual(rec.verdict, .watching)
    }

    func testCheapMultipleProducesPositiveSignal() {
        let deal = DealEntity(businessName: "Cheap", askingPrice: 200_000, reportedSDE: 100_000)
        let rec = DealDecisionEngine.recommend(deal: deal)
        let multipleSignal = rec.signals.first { $0.label == "Multiple" }
        XCTAssertNotNil(multipleSignal)
        XCTAssertEqual(multipleSignal?.polarity, 1)
    }

    func testRichMultipleProducesNegativeSignal() {
        let deal = DealEntity(businessName: "Rich", askingPrice: 1_000_000, reportedSDE: 150_000)
        let rec = DealDecisionEngine.recommend(deal: deal)
        let multipleSignal = rec.signals.first { $0.label == "Multiple" }
        XCTAssertEqual(multipleSignal?.polarity, -1)
    }

    func testDeadDealRollsToNegativeStageSignal() {
        let deal = DealEntity(businessName: "Dead", status: .dead)
        let rec = DealDecisionEngine.recommend(deal: deal)
        let stageSignal = rec.signals.first { $0.label == "Stage" }
        XCTAssertEqual(stageSignal?.polarity, -1)
    }
}
