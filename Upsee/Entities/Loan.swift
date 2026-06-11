import Foundation
import SwiftData
import SwiftUI

@Model
final class Loan {
    var name: String
    var lender: String
    var kindRaw: String
    var originalPrincipal: Decimal
    var currentBalance: Decimal
    var apr: Double            // 0.0625 = 6.25%
    var termMonths: Int        // Original term
    var monthlyPayment: Decimal
    var extraPayment: Decimal
    var startDate: Date
    var taxDeductible: Bool
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var kind: LoanKind {
        get { LoanKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(
        name: String,
        lender: String = "",
        kind: LoanKind = .other,
        originalPrincipal: Decimal,
        currentBalance: Decimal,
        apr: Double,
        termMonths: Int,
        monthlyPayment: Decimal,
        extraPayment: Decimal = 0,
        startDate: Date = Date(),
        taxDeductible: Bool = false
    ) {
        self.name = name
        self.lender = lender
        self.kindRaw = kind.rawValue
        self.originalPrincipal = originalPrincipal
        self.currentBalance = currentBalance
        self.apr = apr
        self.termMonths = termMonths
        self.monthlyPayment = monthlyPayment
        self.extraPayment = extraPayment
        self.startDate = startDate
        self.taxDeductible = taxDeductible
        self.note = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum LoanKind: String, Codable, CaseIterable {
    case mortgage
    case student
    case auto
    case creditCard
    case personal
    case heloc
    case business
    case other

    var displayName: String {
        switch self {
        case .mortgage: return "Mortgage"
        case .student: return "Student Loan"
        case .auto: return "Auto Loan"
        case .creditCard: return "Credit Card"
        case .personal: return "Personal Loan"
        case .heloc: return "HELOC"
        case .business: return "Business Loan"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .mortgage: return "house"
        case .student: return "graduationcap"
        case .auto: return "car"
        case .creditCard: return "creditcard"
        case .personal: return "person.crop.circle"
        case .heloc: return "house.lodge"
        case .business: return "building.2"
        case .other: return "doc.text"
        }
    }

    var tint: Color {
        switch self {
        case .mortgage: return .brown
        case .student: return .blue
        case .auto: return .green
        case .creditCard: return .red
        case .personal: return .orange
        case .heloc: return .purple
        case .business: return .indigo
        case .other: return .secondary
        }
    }
}
