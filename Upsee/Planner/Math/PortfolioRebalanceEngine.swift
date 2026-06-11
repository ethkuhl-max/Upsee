import Foundation

struct AllocationLine: Identifiable {
    let id = UUID()
    let assetClass: AssetClass
    let targetPercent: Double
    let currentPercent: Double
    let drift: Double           // currentPercent - targetPercent
    let driftAbs: Double        // absolute drift
    let targetDollars: Decimal
    let currentDollars: Decimal
    let dollarDelta: Decimal    // currentDollars - targetDollars
    let needsRebalance: Bool
    let suggestedAction: String
}

struct RebalanceSummary {
    let lines: [AllocationLine]
    let totalPortfolio: Decimal
    let targetSumValid: Bool        // true when targets sum to ~1.0
    let maxDriftPercent: Double
    let needsRebalance: Bool
}

enum PortfolioRebalanceEngine {
    static func summarize(
        targets: [TargetAllocation],
        balanceSheetItems: [BalanceSheetItem],
        assetClassMap: [String: AssetClass] = [:]
    ) -> RebalanceSummary {
        // Total investable portfolio = all non-liability balance sheet items.
        let assets = balanceSheetItems.filter { $0.category.isAsset }
        let total = assets.reduce(Decimal(0)) { $0 + $1.amount }
        let totalDouble = NSDecimalNumber(decimal: total).doubleValue

        let current = currentByAssetClass(assets: assets, assetClassMap: assetClassMap)
        let targetSum = targets.reduce(0.0) { $0 + $1.targetPercent }
        let targetSumValid = abs(targetSum - 1.0) < 0.01

        var lines: [AllocationLine] = []
        for t in targets {
            let curDollars = current[t.assetClass] ?? 0
            let curDouble = NSDecimalNumber(decimal: curDollars).doubleValue
            let curPct = totalDouble > 0 ? curDouble / totalDouble : 0
            let drift = curPct - t.targetPercent
            let driftAbs = abs(drift)
            let targetDollars = total * Decimal(t.targetPercent)
            let delta = curDollars - targetDollars
            let needs = driftAbs > t.driftThreshold
            let action: String = {
                if !needs { return "Within band" }
                if delta > 0 {
                    return "Sell ~\(currency(delta)) of \(t.assetClass.displayName)"
                } else {
                    return "Buy ~\(currency(-delta)) of \(t.assetClass.displayName)"
                }
            }()
            lines.append(.init(
                assetClass: t.assetClass,
                targetPercent: t.targetPercent,
                currentPercent: curPct,
                drift: drift,
                driftAbs: driftAbs,
                targetDollars: targetDollars,
                currentDollars: curDollars,
                dollarDelta: delta,
                needsRebalance: needs,
                suggestedAction: action
            ))
        }
        let maxDrift = lines.map { $0.driftAbs }.max() ?? 0
        let any = lines.contains { $0.needsRebalance }
        return RebalanceSummary(
            lines: lines,
            totalPortfolio: total,
            targetSumValid: targetSumValid,
            maxDriftPercent: maxDrift,
            needsRebalance: any
        )
    }

    /// Maps each BalanceSheetItem to an AssetClass. Caller can override the
    /// per-item mapping via the dictionary keyed by item.name; otherwise we
    /// infer from the BalanceSheetCategory.
    private static func currentByAssetClass(
        assets: [BalanceSheetItem],
        assetClassMap: [String: AssetClass]
    ) -> [AssetClass: Decimal] {
        var result: [AssetClass: Decimal] = [:]
        for item in assets {
            let cls = assetClassMap[item.name] ?? inferAssetClass(category: item.category, name: item.name)
            result[cls, default: 0] += item.amount
        }
        return result
    }

    private static func inferAssetClass(category: BalanceSheetCategory, name: String) -> AssetClass {
        let lower = name.lowercased()
        if lower.contains("crypto") || lower.contains("bitcoin") || lower.contains("eth") { return .crypto }
        if lower.contains("intl") || lower.contains("vxus") || lower.contains("emerging") { return .intlStocks }
        if lower.contains("bond") || lower.contains("bnd") || lower.contains("treasury") { return .bonds }
        if lower.contains("reit") || lower.contains("real estate") { return .realEstate }
        switch category {
        case .cash: return .cash
        case .investments, .retirement: return .usStocks
        case .realEstate: return .realEstate
        default: return .other
        }
    }
}
