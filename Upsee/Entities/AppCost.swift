import Foundation
import SwiftData
import SwiftUI

/// A recurring or one-time cost attributed to a specific app. The string-tag
/// pattern (entityKind/entityLabel) matches `TimeEntry` and `JournalEntry` —
/// costs survive an app delete so historical net-profit math stays honest.
@Model
final class AppCost {
    var name: String
    var entityKind: String
    var entityLabel: String
    var amount: Decimal
    var cadenceRaw: String
    var categoryRaw: String
    var startedAt: Date
    var endedAt: Date?
    var note: String
    var createdAt: Date

    var cadence: CostCadence {
        get { CostCadence(rawValue: cadenceRaw) ?? .monthly }
        set { cadenceRaw = newValue.rawValue }
    }

    var category: CostCategory {
        get { CostCategory(rawValue: categoryRaw) ?? .service }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String,
        entityKind: String = "app",
        entityLabel: String,
        amount: Decimal,
        cadence: CostCadence = .monthly,
        category: CostCategory = .service,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.name = name
        self.entityKind = entityKind
        self.entityLabel = entityLabel
        self.amount = amount
        self.cadenceRaw = cadence.rawValue
        self.categoryRaw = category.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = ""
        self.createdAt = Date()
    }

    /// Normalized monthly burn — annual / 12, one-time amortized over 12 months
    /// from `startedAt`. Returns 0 if `endedAt` is in the past at `asOf`.
    func monthlyEquivalent(asOf: Date = Date()) -> Decimal {
        if let endedAt, endedAt < asOf { return 0 }
        switch cadence {
        case .monthly: return amount
        case .annual: return amount / 12
        case .oneTime:
            let months = Calendar.current.dateComponents([.month], from: startedAt, to: asOf).month ?? 0
            return months < 12 ? amount / 12 : 0
        case .quarterly: return amount / 3
        }
    }
}

enum CostCadence: String, Codable, CaseIterable {
    case monthly, annual, quarterly, oneTime

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .quarterly: return "Quarterly"
        case .oneTime: return "One-time"
        }
    }
}

enum CostCategory: String, Codable, CaseIterable {
    case service
    case advertising
    case contractor
    case appleFee
    case infrastructure
    case other

    var displayName: String {
        switch self {
        case .service: return "Service / SaaS"
        case .advertising: return "Advertising"
        case .contractor: return "Contractor"
        case .appleFee: return "Apple Fee"
        case .infrastructure: return "Infrastructure"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .service: return "gear"
        case .advertising: return "megaphone"
        case .contractor: return "person.crop.rectangle"
        case .appleFee: return "applelogo"
        case .infrastructure: return "server.rack"
        case .other: return "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .service: return .blue
        case .advertising: return .orange
        case .contractor: return .purple
        case .appleFee: return .gray
        case .infrastructure: return .teal
        case .other: return .secondary
        }
    }
}
