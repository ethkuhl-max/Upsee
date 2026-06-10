import Foundation
import SwiftData
import SwiftUI

@Model
final class BalanceSheetItem: NetWorthLine {
    var name: String
    var amount: Decimal
    var isAsset: Bool
    var categoryRaw: String
    var createdAt: Date
    var updatedAt: Date

    // Used by the debt payoff planner for liabilities (ignored for assets).
    var apr: Double = 0
    var minimumPayment: Decimal = 0

    var category: BalanceSheetCategory {
        get { BalanceSheetCategory(rawValue: categoryRaw) ?? .otherAsset }
        set {
            categoryRaw = newValue.rawValue
            isAsset = newValue.isAsset
        }
    }

    init(name: String, amount: Decimal = 0, category: BalanceSheetCategory = .cash, apr: Double = 0, minimumPayment: Decimal = 0) {
        self.name = name
        self.amount = amount
        self.isAsset = category.isAsset
        self.categoryRaw = category.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.apr = apr
        self.minimumPayment = minimumPayment
    }
}

enum BalanceSheetCategory: String, Codable, CaseIterable {
    case cash
    case investments
    case retirement
    case realEstate
    case vehicle
    case otherAsset
    case creditCard
    case studentLoan
    case autoLoan
    case mortgage
    case otherLiability

    var isAsset: Bool {
        switch self {
        case .creditCard, .studentLoan, .autoLoan, .mortgage, .otherLiability:
            return false
        default:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .cash: return "Cash & savings"
        case .investments: return "Investments"
        case .retirement: return "Retirement"
        case .realEstate: return "Real estate"
        case .vehicle: return "Vehicle"
        case .otherAsset: return "Other asset"
        case .creditCard: return "Credit card"
        case .studentLoan: return "Student loan"
        case .autoLoan: return "Auto loan"
        case .mortgage: return "Mortgage"
        case .otherLiability: return "Other liability"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: return "banknote"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .retirement: return "figure.walk"
        case .realEstate: return "house"
        case .vehicle: return "car"
        case .otherAsset: return "shippingbox"
        case .creditCard: return "creditcard"
        case .studentLoan: return "graduationcap"
        case .autoLoan: return "car.circle"
        case .mortgage: return "house.lodge"
        case .otherLiability: return "minus.circle"
        }
    }

    static var assetCases: [BalanceSheetCategory] { allCases.filter { $0.isAsset } }
    static var liabilityCases: [BalanceSheetCategory] { allCases.filter { !$0.isAsset } }
}
