import Foundation
import SwiftData

/// A monthly spending target for a single category. Engine compares against
/// transaction outflows in that category for the current calendar month.
@Model
final class Budget {
    var categoryRaw: String
    var monthlyTarget: Decimal
    var rolloverUnused: Bool
    var createdAt: Date
    var updatedAt: Date

    var category: TxCategory {
        get { TxCategory(rawValue: categoryRaw) ?? .uncategorized }
        set { categoryRaw = newValue.rawValue }
    }

    init(category: TxCategory, monthlyTarget: Decimal, rolloverUnused: Bool = false) {
        self.categoryRaw = category.rawValue
        self.monthlyTarget = monthlyTarget
        self.rolloverUnused = rolloverUnused
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
