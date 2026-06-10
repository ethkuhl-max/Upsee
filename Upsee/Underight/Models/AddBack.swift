import Foundation
import FoundationModels

/// An adjustment the seller is claiming against reported earnings to derive SDE.
/// `credibility` is the share of `amount` the engine treats as legitimate (0.0–1.0).
/// Defaults are set per `AddBackCategory` based on how often each line is genuine
/// — owner salary almost always survives diligence, personal meals almost never do.
struct AddBack: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var amount: Decimal
    var category: AddBackCategory
    var credibility: Double
    var note: String?

    init(
        id: UUID = UUID(),
        label: String,
        amount: Decimal,
        category: AddBackCategory,
        credibility: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.label = label
        self.amount = amount
        self.category = category
        self.credibility = credibility ?? category.defaultCredibility
        self.note = note
    }
}

@Generable
enum AddBackCategory: String, Codable, CaseIterable {
    case ownerSalary
    case ownerBenefits
    case interest
    case taxes
    case depreciation
    case amortization
    case oneTimeExpense
    case personalVehicle
    case personalTravel
    case personalMeals
    case familyPayroll
    case rent
    case other

    /// How much of a claimed add-back this category typically survives skeptical review.
    /// 1.0 = essentially always legitimate; 0.0 = almost always fiction.
    var defaultCredibility: Double {
        switch self {
        case .interest, .taxes, .depreciation, .amortization:
            return 1.0
        case .ownerSalary:
            return 1.0
        case .ownerBenefits:
            return 0.9
        case .personalVehicle:
            return 0.6
        case .rent:
            return 0.5
        case .oneTimeExpense:
            return 0.5
        case .familyPayroll:
            return 0.4
        case .personalTravel:
            return 0.3
        case .personalMeals:
            return 0.2
        case .other:
            return 0.5
        }
    }

    var displayName: String {
        switch self {
        case .ownerSalary: return "Owner Salary"
        case .ownerBenefits: return "Owner Benefits"
        case .interest: return "Interest"
        case .taxes: return "Taxes"
        case .depreciation: return "Depreciation"
        case .amortization: return "Amortization"
        case .oneTimeExpense: return "One-Time Expense"
        case .personalVehicle: return "Personal Vehicle"
        case .personalTravel: return "Personal Travel"
        case .personalMeals: return "Personal Meals"
        case .familyPayroll: return "Family Payroll"
        case .rent: return "Rent / Lease"
        case .other: return "Other"
        }
    }
}
