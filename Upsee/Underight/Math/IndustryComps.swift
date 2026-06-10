import Foundation
import FoundationModels

/// Static industry comparable multiples (price ÷ SDE) used as v1 sanity reference.
/// Sources: BizBuySell aggregate insights, ETA Twitter consensus, BVR-style reference
/// ranges. Numbers reflect 2025 deal flow. Values are intentionally conservative —
/// Underight's voice is the skeptic's, so where ranges disagree we lean toward the
/// median that survives downside scenarios.
@Generable
enum IndustryCategory: String, Codable, CaseIterable {
    case hvac
    case plumbing
    case electrical
    case landscaping
    case roofing
    case generalContracting
    case laundromat
    case carWash
    case vendingRoute
    case restaurant
    case foodTruck
    case catering
    case ecommerce
    case contentSite
    case saas
    case professionalServices
    case accountingFirm
    case lawFirm
    case dental
    case medicalPractice
    case manufacturing
    case distribution
    case other

    var displayName: String {
        switch self {
        case .hvac: return "HVAC"
        case .plumbing: return "Plumbing"
        case .electrical: return "Electrical"
        case .landscaping: return "Landscaping"
        case .roofing: return "Roofing"
        case .generalContracting: return "General Contracting"
        case .laundromat: return "Laundromat"
        case .carWash: return "Car Wash"
        case .vendingRoute: return "Vending Route"
        case .restaurant: return "Restaurant"
        case .foodTruck: return "Food Truck"
        case .catering: return "Catering"
        case .ecommerce: return "Ecommerce"
        case .contentSite: return "Content Site"
        case .saas: return "SaaS"
        case .professionalServices: return "Professional Services"
        case .accountingFirm: return "Accounting Firm"
        case .lawFirm: return "Law Firm"
        case .dental: return "Dental Practice"
        case .medicalPractice: return "Medical Practice"
        case .manufacturing: return "Manufacturing"
        case .distribution: return "Distribution"
        case .other: return "Other"
        }
    }
}

/// Whether an industry's comp multiple is taken against SDE or gross revenue.
enum ValuationBasis: String, Codable, Equatable {
    case sde
    case revenue
}

struct IndustryMultipleRange: Codable, Equatable {
    let low: Double
    let median: Double
    let high: Double
    let note: String?
    /// Optional for backward compatibility with analyses saved before the basis existed.
    var basis: ValuationBasis? = .sde

    var valuationBasis: ValuationBasis { basis ?? .sde }
}

enum IndustryComps {
    static func range(for category: IndustryCategory) -> IndustryMultipleRange {
        switch category {
        case .hvac:                return .init(low: 2.0, median: 2.8, high: 3.5, note: "Recurring service contracts push multiple toward high end.")
        case .plumbing:            return .init(low: 2.0, median: 2.6, high: 3.3, note: nil)
        case .electrical:          return .init(low: 2.2, median: 2.9, high: 3.6, note: nil)
        case .landscaping:         return .init(low: 1.8, median: 2.5, high: 3.2, note: "Seasonal cash flow; verify off-season coverage.")
        case .roofing:             return .init(low: 1.8, median: 2.4, high: 3.0, note: "Storm-dependent revenue spikes inflate trailing.")
        case .generalContracting:  return .init(low: 1.5, median: 2.2, high: 2.8, note: "Project-based — check backlog quality.")
        case .laundromat:          return .init(low: 2.5, median: 3.5, high: 5.0, note: "Real estate and equipment age dominate the multiple.")
        case .carWash:             return .init(low: 3.0, median: 4.5, high: 6.0, note: "Tunnel vs in-bay automatic material to multiple.")
        case .vendingRoute:        return .init(low: 1.5, median: 2.0, high: 2.8, note: "Location contracts < 12 months are a red flag.")
        case .restaurant:          return .init(low: 1.5, median: 2.0, high: 2.8, note: "Lease terms drive value as much as cash flow.")
        case .foodTruck:           return .init(low: 1.0, median: 1.5, high: 2.2, note: nil)
        case .catering:            return .init(low: 1.8, median: 2.4, high: 3.0, note: nil)
        case .ecommerce:           return .init(low: 2.0, median: 2.8, high: 4.0, note: "Customer acquisition cost trend is the real story.")
        case .contentSite:         return .init(low: 2.5, median: 3.5, high: 5.0, note: "Heavy traffic concentration risk on Google updates.")
        case .saas:                return .init(low: 3.0, median: 4.5, high: 7.0, note: "Net revenue retention separates the medians from the highs.")
        case .professionalServices: return .init(low: 1.8, median: 2.5, high: 3.2, note: "Owner-dependent — replacement risk is the question.")
        case .accountingFirm:      return .init(low: 0.9, median: 1.1, high: 1.4, note: "Multiple of gross revenue, not SDE — common industry convention.", basis: .revenue)
        case .lawFirm:             return .init(low: 0.8, median: 1.0, high: 1.3, note: "Practice-area-dependent. Multiple of gross revenue.", basis: .revenue)
        case .dental:              return .init(low: 0.6, median: 0.75, high: 0.95, note: "Multiple of revenue, not SDE — industry convention.", basis: .revenue)
        case .medicalPractice:     return .init(low: 0.5, median: 0.7, high: 0.9, note: "Multiple of revenue, not SDE — industry convention.", basis: .revenue)
        case .manufacturing:       return .init(low: 3.0, median: 4.0, high: 5.5, note: "Customer concentration > 25% is a significant haircut.")
        case .distribution:        return .init(low: 2.5, median: 3.5, high: 4.5, note: "Supplier and customer concentration both matter.")
        case .other:               return .init(low: 2.0, median: 3.0, high: 4.0, note: "Generic SMB range — categorize for a tighter read.")
        }
    }
}
