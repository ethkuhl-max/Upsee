import Foundation
import SwiftData
import SwiftUI

/// Estate planning document presence + currency. The point is the checklist —
/// real advisors hand clients a list. Tracking last-reviewed dates surfaces
/// stale beneficiaries / out-of-date wills.
@Model
final class EstateDocument {
    var kindRaw: String
    var present: Bool
    var lastReviewedAt: Date?
    var attorney: String
    var location: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var kind: EstateDocKind {
        get { EstateDocKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: EstateDocKind, present: Bool = false) {
        self.kindRaw = kind.rawValue
        self.present = present
        self.attorney = ""
        self.location = ""
        self.note = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// True if marked present and not reviewed in 5+ years.
    var isStale: Bool {
        guard present, let last = lastReviewedAt else { return present == false }
        let years = Calendar.current.dateComponents([.year], from: last, to: Date()).year ?? 0
        return years >= 5
    }

    var yearsSinceReview: Int? {
        guard let last = lastReviewedAt else { return nil }
        return Calendar.current.dateComponents([.year], from: last, to: Date()).year
    }
}

enum EstateDocKind: String, Codable, CaseIterable {
    case will
    case durablePOA
    case healthcarePOA
    case hipaaRelease
    case livingWill
    case trust
    case beneficiaryReview
    case lifeInsuranceBenef
    case retirementBenef
    case digitalAssetInventory
    case letterOfInstruction
    case other

    var displayName: String {
        switch self {
        case .will: return "Will"
        case .durablePOA: return "Durable Power of Attorney"
        case .healthcarePOA: return "Healthcare Power of Attorney"
        case .hipaaRelease: return "HIPAA Release"
        case .livingWill: return "Living Will / Advance Directive"
        case .trust: return "Revocable Trust"
        case .beneficiaryReview: return "Beneficiary Designations Review"
        case .lifeInsuranceBenef: return "Life Insurance Beneficiaries"
        case .retirementBenef: return "Retirement Account Beneficiaries"
        case .digitalAssetInventory: return "Digital Asset Inventory"
        case .letterOfInstruction: return "Letter of Instruction"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .will: return "doc.text"
        case .durablePOA, .healthcarePOA: return "person.text.rectangle"
        case .hipaaRelease: return "lock.doc"
        case .livingWill: return "heart.text.square"
        case .trust: return "building.columns"
        case .beneficiaryReview, .lifeInsuranceBenef, .retirementBenef: return "person.2"
        case .digitalAssetInventory: return "key.horizontal"
        case .letterOfInstruction: return "envelope"
        case .other: return "doc"
        }
    }

    var isCore: Bool {
        switch self {
        case .will, .durablePOA, .healthcarePOA, .beneficiaryReview, .hipaaRelease: return true
        default: return false
        }
    }

    static var standardChecklist: [EstateDocKind] {
        [.will, .durablePOA, .healthcarePOA, .hipaaRelease, .livingWill, .trust,
         .beneficiaryReview, .lifeInsuranceBenef, .retirementBenef, .digitalAssetInventory,
         .letterOfInstruction]
    }
}
