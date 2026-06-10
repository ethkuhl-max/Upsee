import XCTest
@testable import Upsee

final class FinancialHealthEngineTests: XCTestCase {
    func testStrongProfileScoresHigh() {
        let input = FinancialHealthInputs(
            monthlyIncome: 20_000,
            monthlyExpenses: 10_000,
            liquidSavings: 90_000,           // 9 months
            totalAssets: 1_000_000,
            totalLiabilities: 100_000,       // 10% leverage
            monthlyDebtPayments: 1_000,      // 5% DTI
            largestIncomeShare: 0.4
        )
        let h = FinancialHealthEngine.assess(input)
        XCTAssertGreaterThanOrEqual(h.overall, 85)
        XCTAssertTrue(["A", "B"].contains(h.grade))
        XCTAssertTrue(h.recommendations.isEmpty)
    }

    func testWeakProfileScoresLowWithRecommendations() {
        let input = FinancialHealthInputs(
            monthlyIncome: 8_000,
            monthlyExpenses: 7_800,          // ~3% savings
            liquidSavings: 4_000,            // < 1 month
            totalAssets: 300_000,
            totalLiabilities: 270_000,       // 90% leverage
            monthlyDebtPayments: 3_600,      // 45% DTI
            largestIncomeShare: 0.95
        )
        let h = FinancialHealthEngine.assess(input)
        XCTAssertLessThan(h.overall, 40)
        XCTAssertEqual(h.grade, "F")
        XCTAssertFalse(h.recommendations.isEmpty)
    }

    func testSubscoreCount() {
        let input = FinancialHealthInputs(monthlyIncome: 10_000, monthlyExpenses: 6_000, liquidSavings: 36_000,
                                          totalAssets: 500_000, totalLiabilities: 150_000, monthlyDebtPayments: 1_500,
                                          largestIncomeShare: 0.5)
        let h = FinancialHealthEngine.assess(input)
        XCTAssertEqual(h.subscores.count, 5)
        XCTAssertTrue(h.overall >= 0 && h.overall <= 100)
    }

    func testEmergencyFundScales() {
        func score(months: Decimal) -> Int {
            FinancialHealthEngine.assess(FinancialHealthInputs(
                monthlyIncome: 10_000, monthlyExpenses: 5_000, liquidSavings: months * 5_000,
                totalAssets: 100_000, totalLiabilities: 0, monthlyDebtPayments: 0, largestIncomeShare: 0.5
            )).subscores.first { $0.name == "Emergency fund" }!.score
        }
        XCTAssertLessThan(score(months: 1), score(months: 6))
    }
}
