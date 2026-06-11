import XCTest
@testable import Upsee

final class PortfolioRebalanceEngineTests: XCTestCase {
    func testWithinBandsWhenAtTarget() {
        let stocks = BalanceSheetItem(name: "VTI", amount: 70_000, category: .investments)
        let bonds = BalanceSheetItem(name: "BND", amount: 30_000, category: .investments)
        let targets = [
            TargetAllocation(assetClass: .usStocks, targetPercent: 0.7),
            TargetAllocation(assetClass: .bonds, targetPercent: 0.3),
        ]
        let s = PortfolioRebalanceEngine.summarize(targets: targets, balanceSheetItems: [stocks, bonds])
        XCTAssertFalse(s.needsRebalance)
    }

    func testDriftFlaggedWhenBeyondThreshold() {
        let stocks = BalanceSheetItem(name: "VTI", amount: 90_000, category: .investments)
        let bonds = BalanceSheetItem(name: "BND", amount: 10_000, category: .investments)
        let targets = [
            TargetAllocation(assetClass: .usStocks, targetPercent: 0.7, driftThreshold: 0.05),
            TargetAllocation(assetClass: .bonds, targetPercent: 0.3, driftThreshold: 0.05),
        ]
        let s = PortfolioRebalanceEngine.summarize(targets: targets, balanceSheetItems: [stocks, bonds])
        XCTAssertTrue(s.needsRebalance)
    }

    func testTargetSumValidationCatchesBadTargets() {
        let targets = [TargetAllocation(assetClass: .usStocks, targetPercent: 0.5)]
        let s = PortfolioRebalanceEngine.summarize(targets: targets, balanceSheetItems: [])
        XCTAssertFalse(s.targetSumValid)
    }

    func testSuggestsBuyForUnderAllocated() {
        let stocks = BalanceSheetItem(name: "VTI", amount: 50_000, category: .investments)
        let bonds = BalanceSheetItem(name: "BND", amount: 50_000, category: .investments)
        let targets = [
            TargetAllocation(assetClass: .usStocks, targetPercent: 0.7),
            TargetAllocation(assetClass: .bonds, targetPercent: 0.3),
        ]
        let s = PortfolioRebalanceEngine.summarize(targets: targets, balanceSheetItems: [stocks, bonds])
        let usLine = s.lines.first { $0.assetClass == .usStocks }!
        XCTAssertTrue(usLine.suggestedAction.contains("Buy"))
    }
}
