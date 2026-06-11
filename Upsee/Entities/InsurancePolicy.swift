import Foundation
import SwiftData
import SwiftUI

@Model
final class InsurancePolicy {
    var name: String
    var insurer: String
    var kindRaw: String
    var coverageAmount: Decimal
    var monthlyPremium: Decimal
    var beneficiary: String
    var policyNumber: String
    var renewalDate: Date?
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var kind: InsuranceKind {
        get { InsuranceKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(
        name: String,
        insurer: String = "",
        kind: InsuranceKind,
        coverageAmount: Decimal,
        monthlyPremium: Decimal = 0,
        beneficiary: String = "",
        renewalDate: Date? = nil
    ) {
        self.name = name
        self.insurer = insurer
        self.kindRaw = kind.rawValue
        self.coverageAmount = coverageAmount
        self.monthlyPremium = monthlyPremium
        self.beneficiary = beneficiary
        self.policyNumber = ""
        self.renewalDate = renewalDate
        self.note = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum InsuranceKind: String, Codable, CaseIterable {
    case termLife
    case wholeLife
    case disability
    case umbrella
    case homeowners
    case renters
    case auto
    case health
    case longTermCare
    case other

    var displayName: String {
        switch self {
        case .termLife: return "Term Life"
        case .wholeLife: return "Whole Life"
        case .disability: return "Disability"
        case .umbrella: return "Umbrella"
        case .homeowners: return "Homeowners"
        case .renters: return "Renters"
        case .auto: return "Auto"
        case .health: return "Health"
        case .longTermCare: return "Long-Term Care"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .termLife, .wholeLife: return "person.fill.checkmark"
        case .disability: return "figure.roll"
        case .umbrella: return "umbrella"
        case .homeowners: return "house.lodge"
        case .renters: return "key"
        case .auto: return "car"
        case .health: return "cross.case"
        case .longTermCare: return "bed.double"
        case .other: return "shield"
        }
    }

    var tint: Color {
        switch self {
        case .termLife, .wholeLife: return .blue
        case .disability: return .orange
        case .umbrella: return .indigo
        case .homeowners, .renters: return .brown
        case .auto: return .green
        case .health: return .red
        case .longTermCare: return .purple
        case .other: return .secondary
        }
    }

    var isLife: Bool {
        self == .termLife || self == .wholeLife
    }
}
