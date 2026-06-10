import Foundation
import SwiftData

/// A single due-diligence checklist line, linked to a saved deal by `dealID`
/// (mirrors `DealEntity.dealID`, matching how analyses are upserted).
@Model
final class DiligenceItem {
    var dealID: UUID = UUID()
    var text: String
    var isDone: Bool
    var sortIndex: Int
    var createdAt: Date

    init(dealID: UUID, text: String, isDone: Bool = false, sortIndex: Int = 0) {
        self.dealID = dealID
        self.text = text
        self.isDone = isDone
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }
}

/// Default diligence checklists — a shared backbone plus industry-specific probes.
enum DiligenceTemplate {
    static func items(for industry: IndustryCategory) -> [String] {
        baseItems + specificItems(for: industry)
    }

    private static let baseItems: [String] = [
        "3 years of tax returns reconciled to the P&L",
        "Trailing-twelve-month bank statements vs. reported revenue",
        "Verify every add-back with source documentation",
        "Customer concentration: top 10 as % of revenue",
        "Owner's true weekly hours and role in operations",
        "Employee roster, comp, and key-person dependencies",
        "Lease terms, renewal options, and assignability",
        "Outstanding debt, liens, and UCC filings",
        "Pending litigation or regulatory issues",
        "Reason for sale — corroborated independently",
    ]

    private static func specificItems(for industry: IndustryCategory) -> [String] {
        switch industry {
        case .hvac, .plumbing, .electrical, .generalContracting:
            return [
                "Recurring service-contract base and renewal rate",
                "Technician licenses and certifications transferability",
                "Open warranty/callback liabilities",
            ]
        case .landscaping, .roofing:
            return [
                "Seasonality: off-season revenue coverage",
                "Equipment age, condition, and replacement schedule",
            ]
        case .laundromat, .carWash:
            return [
                "Equipment age and remaining useful life",
                "Real estate ownership vs. lease and utility costs",
            ]
        case .restaurant, .foodTruck, .catering:
            return [
                "Health inspection history",
                "Food and labor cost percentages vs. industry",
                "Lease and any liquor-license transfer",
            ]
        case .ecommerce, .contentSite, .saas:
            return [
                "Traffic sources and concentration (Google/Meta dependency)",
                "Customer acquisition cost and retention/churn trend",
                "Platform/account transferability and IP ownership",
            ]
        case .accountingFirm, .lawFirm, .professionalServices:
            return [
                "Client retention and revenue per client",
                "Owner's personal goodwill vs. transferable book",
                "Non-compete and transition support terms",
            ]
        case .dental, .medicalPractice:
            return [
                "Payer mix and insurance contract assignability",
                "Provider credentialing and licensing transfer",
                "Equipment and patient-records system condition",
            ]
        case .manufacturing, .distribution:
            return [
                "Supplier concentration and contract terms",
                "Inventory valuation and obsolescence",
                "Capex needs and equipment maintenance logs",
            ]
        case .vendingRoute:
            return [
                "Location-contract terms and remaining duration",
                "Machine age and route density",
            ]
        case .other:
            return []
        }
    }
}
