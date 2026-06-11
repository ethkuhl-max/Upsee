import Foundation
import SwiftData
import SwiftUI

/// Target % allocation for a single asset class. Sum of all TargetAllocation
/// `targetPercent` should equal 1.0 — UI surfaces a warning if not.
@Model
final class TargetAllocation {
    var assetClassRaw: String
    var targetPercent: Double         // 0.0...1.0
    var driftThreshold: Double        // 0.05 = rebalance when >5% off
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var assetClass: AssetClass {
        get { AssetClass(rawValue: assetClassRaw) ?? .other }
        set { assetClassRaw = newValue.rawValue }
    }

    init(assetClass: AssetClass, targetPercent: Double, driftThreshold: Double = 0.05) {
        self.assetClassRaw = assetClass.rawValue
        self.targetPercent = targetPercent
        self.driftThreshold = driftThreshold
        self.note = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum AssetClass: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case usStocks
    case intlStocks
    case bonds
    case realEstate
    case cash
    case alternatives
    case crypto
    case other

    var displayName: String {
        switch self {
        case .usStocks: return "US Stocks"
        case .intlStocks: return "Intl Stocks"
        case .bonds: return "Bonds"
        case .realEstate: return "Real Estate"
        case .cash: return "Cash"
        case .alternatives: return "Alternatives"
        case .crypto: return "Crypto"
        case .other: return "Other"
        }
    }

    var tint: Color {
        switch self {
        case .usStocks: return .blue
        case .intlStocks: return .cyan
        case .bonds: return .purple
        case .realEstate: return .brown
        case .cash: return .green
        case .alternatives: return .orange
        case .crypto: return .yellow
        case .other: return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .usStocks: return "chart.line.uptrend.xyaxis"
        case .intlStocks: return "globe.americas"
        case .bonds: return "doc.text"
        case .realEstate: return "house"
        case .cash: return "dollarsign.circle"
        case .alternatives: return "diamond"
        case .crypto: return "bitcoinsign.circle"
        case .other: return "circle"
        }
    }
}

/// Free-text IPS body that the user fills in once and rereads quarterly.
@Model
final class IPSDocument {
    var body: String
    var riskToleranceRaw: String
    var timeHorizonYears: Int
    var lastReviewedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var riskTolerance: RiskTolerance {
        get { RiskTolerance(rawValue: riskToleranceRaw) ?? .moderate }
        set { riskToleranceRaw = newValue.rawValue }
    }

    init() {
        self.body = ""
        self.riskToleranceRaw = RiskTolerance.moderate.rawValue
        self.timeHorizonYears = 20
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum RiskTolerance: String, Codable, CaseIterable {
    case conservative
    case moderate
    case aggressive

    var displayName: String {
        switch self {
        case .conservative: return "Conservative"
        case .moderate: return "Moderate"
        case .aggressive: return "Aggressive"
        }
    }

    /// "Default" allocation a planner might suggest as a starting point.
    var suggestedStockBondMix: (stocks: Double, bonds: Double) {
        switch self {
        case .conservative: return (0.4, 0.6)
        case .moderate: return (0.7, 0.3)
        case .aggressive: return (0.9, 0.1)
        }
    }
}
