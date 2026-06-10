import Foundation
import SwiftData

/// A frozen-at-a-point-in-time view of the user's balance sheet. The trend over
/// many snapshots is the headline chart on the Wealth view. Captured manually
/// today; eventually a monthly auto-capture cron is the goal.
@Model
final class NetWorthSnapshot {
    var date: Date
    var totalAssets: Decimal
    var totalLiabilities: Decimal

    var cashAmount: Decimal
    var investmentsAmount: Decimal
    var retirementAmount: Decimal
    var realEstateAmount: Decimal
    var vehicleAmount: Decimal
    var otherAssetAmount: Decimal

    var creditCardAmount: Decimal
    var studentLoanAmount: Decimal
    var autoLoanAmount: Decimal
    var mortgageAmount: Decimal
    var otherLiabilityAmount: Decimal

    var note: String
    var createdAt: Date

    init(
        date: Date = Date(),
        totalAssets: Decimal = 0,
        totalLiabilities: Decimal = 0,
        cashAmount: Decimal = 0,
        investmentsAmount: Decimal = 0,
        retirementAmount: Decimal = 0,
        realEstateAmount: Decimal = 0,
        vehicleAmount: Decimal = 0,
        otherAssetAmount: Decimal = 0,
        creditCardAmount: Decimal = 0,
        studentLoanAmount: Decimal = 0,
        autoLoanAmount: Decimal = 0,
        mortgageAmount: Decimal = 0,
        otherLiabilityAmount: Decimal = 0,
        note: String = ""
    ) {
        self.date = date
        self.totalAssets = totalAssets
        self.totalLiabilities = totalLiabilities
        self.cashAmount = cashAmount
        self.investmentsAmount = investmentsAmount
        self.retirementAmount = retirementAmount
        self.realEstateAmount = realEstateAmount
        self.vehicleAmount = vehicleAmount
        self.otherAssetAmount = otherAssetAmount
        self.creditCardAmount = creditCardAmount
        self.studentLoanAmount = studentLoanAmount
        self.autoLoanAmount = autoLoanAmount
        self.mortgageAmount = mortgageAmount
        self.otherLiabilityAmount = otherLiabilityAmount
        self.note = note
        self.createdAt = Date()
    }

    var netWorth: Decimal { totalAssets - totalLiabilities }

    /// Capture a snapshot from the current BalanceSheetItem set.
    static func capture(from items: [BalanceSheetItem], date: Date = Date(), note: String = "") -> NetWorthSnapshot {
        let s = NetWorthSnapshot(date: date, note: note)
        for item in items {
            switch item.category {
            case .cash: s.cashAmount += item.amount
            case .investments: s.investmentsAmount += item.amount
            case .retirement: s.retirementAmount += item.amount
            case .realEstate: s.realEstateAmount += item.amount
            case .vehicle: s.vehicleAmount += item.amount
            case .otherAsset: s.otherAssetAmount += item.amount
            case .creditCard: s.creditCardAmount += item.amount
            case .studentLoan: s.studentLoanAmount += item.amount
            case .autoLoan: s.autoLoanAmount += item.amount
            case .mortgage: s.mortgageAmount += item.amount
            case .otherLiability: s.otherLiabilityAmount += item.amount
            }
        }
        s.totalAssets = s.cashAmount + s.investmentsAmount + s.retirementAmount + s.realEstateAmount + s.vehicleAmount + s.otherAssetAmount
        s.totalLiabilities = s.creditCardAmount + s.studentLoanAmount + s.autoLoanAmount + s.mortgageAmount + s.otherLiabilityAmount
        return s
    }
}
