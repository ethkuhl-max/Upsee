import Foundation

struct AssetAllocationSlice: Identifiable, Equatable {
    var id: String { category.rawValue }
    let category: BalanceSheetCategory
    let amount: Decimal
    let percentage: Double
}

struct AssetAllocationSummary: Equatable {
    let totalAssets: Decimal
    let slices: [AssetAllocationSlice]
    /// Categories with > threshold % of total assets — concentration alert candidates.
    let concentrationFlags: [BalanceSheetCategory]
}

enum AssetAllocationEngine {
    static func summarize(_ items: [BalanceSheetItem], concentrationThreshold: Double = 0.40) -> AssetAllocationSummary {
        let assets = items.filter { $0.isAsset }
        let total = assets.reduce(Decimal(0)) { $0 + $1.amount }
        let grouped = Dictionary(grouping: assets) { $0.category }

        let totalDouble = NSDecimalNumber(decimal: total).doubleValue
        var slices: [AssetAllocationSlice] = []
        for category in BalanceSheetCategory.assetCases {
            let amount = grouped[category]?.reduce(Decimal(0)) { $0 + $1.amount } ?? 0
            let amountDouble = NSDecimalNumber(decimal: amount).doubleValue
            let pct = totalDouble > 0 ? amountDouble / totalDouble : 0
            if amount > 0 {
                slices.append(AssetAllocationSlice(category: category, amount: amount, percentage: pct))
            }
        }
        slices.sort { $0.amount > $1.amount }

        let flags = slices
            .filter { $0.percentage > concentrationThreshold && BalanceSheetCategory.assetCases.count > 1 }
            .map { $0.category }

        return AssetAllocationSummary(totalAssets: total, slices: slices, concentrationFlags: flags)
    }
}
