import XCTest
@testable import Upsee

final class NetWorthEngineTests: XCTestCase {
    private struct Line: NetWorthLine {
        let amount: Decimal
        let isAsset: Bool
    }

    private func d(_ x: Decimal) -> Double { NSDecimalNumber(decimal: x).doubleValue }

    func testNetWorthIsAssetsMinusLiabilities() {
        let items = [
            Line(amount: 50_000, isAsset: true),
            Line(amount: 200_000, isAsset: true),
            Line(amount: 30_000, isAsset: false),
            Line(amount: 120_000, isAsset: false),
        ]
        let s = NetWorthEngine.summarize(items)
        XCTAssertEqual(d(s.totalAssets), 250_000, accuracy: 0.01)
        XCTAssertEqual(d(s.totalLiabilities), 150_000, accuracy: 0.01)
        XCTAssertEqual(d(s.netWorth), 100_000, accuracy: 0.01)
    }

    func testLeverageRatio() {
        let items = [
            Line(amount: 100_000, isAsset: true),
            Line(amount: 40_000, isAsset: false),
        ]
        let s = NetWorthEngine.summarize(items)
        XCTAssertEqual(s.leverageRatio, 0.4, accuracy: 0.0001)
    }

    func testEmptyIsZero() {
        let s = NetWorthEngine.summarize([Line]())
        XCTAssertEqual(d(s.netWorth), 0)
        XCTAssertEqual(s.leverageRatio, 0)
    }

    func testNegativeNetWorth() {
        let items = [
            Line(amount: 10_000, isAsset: true),
            Line(amount: 60_000, isAsset: false),
        ]
        let s = NetWorthEngine.summarize(items)
        XCTAssertEqual(d(s.netWorth), -50_000, accuracy: 0.01)
    }
}
