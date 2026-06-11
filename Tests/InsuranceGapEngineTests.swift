import XCTest
@testable import Upsee

final class InsuranceGapEngineTests: XCTestCase {
    func testLifeNeedFollowsTenTimesIncome() {
        let s = InsuranceGapEngine.summarize(
            policies: [],
            annualIncome: 100_000,
            netWorth: 0,
            monthlyExpenses: 5_000
        )
        let life = s.lines.first { $0.kind == .termLife }!
        // 10× income or DIME (debt=0, income×10=1M, mortgage=0) → 1M.
        XCTAssertEqual(NSDecimalNumber(decimal: life.need).doubleValue, 1_000_000, accuracy: 1)
    }

    func testDIMEDominatesWhenDebtIsLarge() {
        let s = InsuranceGapEngine.summarize(
            policies: [],
            annualIncome: 100_000,
            netWorth: 0,
            monthlyExpenses: 5_000,
            debt: 100_000,
            mortgageBalance: 500_000,
            yearsOfIncomeReplacement: 10
        )
        let life = s.lines.first { $0.kind == .termLife }!
        // DIME: 100k + 1M + 500k = 1.6M; 10× income = 1M; DIME wins.
        XCTAssertEqual(NSDecimalNumber(decimal: life.need).doubleValue, 1_600_000, accuracy: 1)
    }

    func testAdequateLifeCoverageMarkedAdequate() {
        let policy = InsurancePolicy(name: "Term", kind: .termLife, coverageAmount: 2_000_000)
        let s = InsuranceGapEngine.summarize(
            policies: [policy],
            annualIncome: 100_000,
            netWorth: 0,
            monthlyExpenses: 5_000
        )
        let life = s.lines.first { $0.kind == .termLife }!
        XCTAssertEqual(life.status, .adequate)
    }

    func testUmbrellaScalesWithNetWorth() {
        let s = InsuranceGapEngine.summarize(
            policies: [],
            annualIncome: 100_000,
            netWorth: 3_500_000,
            monthlyExpenses: 5_000
        )
        let umbrella = s.lines.first { $0.kind == .umbrella }!
        XCTAssertEqual(NSDecimalNumber(decimal: umbrella.need).doubleValue, 3_500_000, accuracy: 1)
    }

    func testMissingPropertyInsuranceFlagged() {
        let s = InsuranceGapEngine.summarize(
            policies: [],
            annualIncome: 100_000,
            netWorth: 0,
            monthlyExpenses: 5_000
        )
        XCTAssertTrue(s.lines.contains { $0.kind == .renters })
        XCTAssertTrue(s.lines.contains { $0.kind == .auto })
    }
}
