import Foundation

/// A single line on the balance sheet. Pure protocol so the engine stays testable
/// without SwiftData. `BalanceSheetItem` conforms.
protocol NetWorthLine {
    var amount: Decimal { get }
    var isAsset: Bool { get }
}

struct NetWorthSummary: Equatable {
    let totalAssets: Decimal
    let totalLiabilities: Decimal

    var netWorth: Decimal { totalAssets - totalLiabilities }

    /// Liabilities as a fraction of assets (0 when there are no assets).
    var leverageRatio: Double {
        let assets = NSDecimalNumber(decimal: totalAssets).doubleValue
        let liabilities = NSDecimalNumber(decimal: totalLiabilities).doubleValue
        return assets > 0 ? liabilities / assets : 0
    }
}

enum NetWorthEngine {
    static func summarize<T: NetWorthLine>(_ items: [T]) -> NetWorthSummary {
        let assets = items.filter { $0.isAsset }.reduce(Decimal(0)) { $0 + $1.amount }
        let liabilities = items.filter { !$0.isAsset }.reduce(Decimal(0)) { $0 + $1.amount }
        return NetWorthSummary(totalAssets: assets, totalLiabilities: liabilities)
    }
}
