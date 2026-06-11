import XCTest
@testable import Upsee

final class RiskProfileEngineTests: XCTestCase {
    func testAllConservativeAnswersScoreLow() {
        let answers = Array(repeating: 0, count: RiskProfileEngine.questions.count)
        let p = RiskProfileEngine.score(answers: answers)
        XCTAssertEqual(p.score, 0)
        XCTAssertEqual(p.band, .conservative)
        XCTAssertLessThan(p.equityPct, p.bondPct)   // bond-heavy
    }

    func testAllAggressiveAnswersScoreHigh() {
        let answers = Array(repeating: 3, count: RiskProfileEngine.questions.count)
        let p = RiskProfileEngine.score(answers: answers)
        XCTAssertEqual(p.score, 100)
        XCTAssertEqual(p.band, .aggressive)
        XCTAssertGreaterThanOrEqual(p.equityPct, 85)
    }

    func testAllocationSumsTo100() {
        for score in stride(from: 0, through: 100, by: 10) {
            let a = RiskProfileEngine.allocation(forScore: score)
            XCTAssertEqual(a.equity + a.bond + a.cash, 100, "score \(score)")
        }
    }

    func testEquityRisesWithScore() {
        let low = RiskProfileEngine.allocation(forScore: 10).equity
        let high = RiskProfileEngine.allocation(forScore: 90).equity
        XCTAssertGreaterThan(high, low)
    }

    func testMidAnswersAreModerate() {
        let answers = Array(repeating: 2, count: RiskProfileEngine.questions.count)
        let p = RiskProfileEngine.score(answers: answers)
        XCTAssertEqual(p.score, 67)  // 12/18
        XCTAssertEqual(p.band, .moderateAggressive)
    }
}
