import Foundation
import SwiftData
import SwiftUI

/// A single posted transaction. Source-of-truth for actual money movement —
/// `BalanceSheetItem` is a periodic snapshot derived from these. Account is
/// string-tagged so renaming/deleting accounts doesn't orphan history.
@Model
final class Transaction {
    var date: Date
    var amount: Decimal      // Signed: positive = inflow, negative = outflow
    var merchant: String
    var rawDescription: String
    var accountName: String
    var categoryRaw: String
    var sourceRaw: String
    var note: String
    var importBatchID: String?
    var createdAt: Date

    var category: TxCategory {
        get { TxCategory(rawValue: categoryRaw) ?? .uncategorized }
        set { categoryRaw = newValue.rawValue }
    }

    var source: TxSource {
        get { TxSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        date: Date,
        amount: Decimal,
        merchant: String,
        rawDescription: String = "",
        accountName: String,
        category: TxCategory = .uncategorized,
        source: TxSource = .manual,
        importBatchID: String? = nil
    ) {
        self.date = date
        self.amount = amount
        self.merchant = merchant
        self.rawDescription = rawDescription.isEmpty ? merchant : rawDescription
        self.accountName = accountName
        self.categoryRaw = category.rawValue
        self.sourceRaw = source.rawValue
        self.note = ""
        self.importBatchID = importBatchID
        self.createdAt = Date()
    }

    var isInflow: Bool { amount > 0 }
    var isOutflow: Bool { amount < 0 }
    var absAmount: Decimal { amount < 0 ? -amount : amount }
}

enum TxCategory: String, Codable, CaseIterable {
    case income, housing, food, transport, health, utilities
    case subscriptions, entertainment, shopping, education
    case savings, investment, taxes, fees
    case business, transfer, gift, charity
    case uncategorized

    var displayName: String {
        switch self {
        case .income: return "Income"
        case .housing: return "Housing"
        case .food: return "Food"
        case .transport: return "Transport"
        case .health: return "Health"
        case .utilities: return "Utilities"
        case .subscriptions: return "Subscriptions"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .education: return "Education"
        case .savings: return "Savings"
        case .investment: return "Investment"
        case .taxes: return "Taxes"
        case .fees: return "Fees"
        case .business: return "Business"
        case .transfer: return "Transfer"
        case .gift: return "Gift"
        case .charity: return "Charity"
        case .uncategorized: return "Uncategorized"
        }
    }

    var systemImage: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .housing: return "house"
        case .food: return "fork.knife"
        case .transport: return "car"
        case .health: return "heart.text.square"
        case .utilities: return "bolt"
        case .subscriptions: return "repeat.circle"
        case .entertainment: return "popcorn"
        case .shopping: return "bag"
        case .education: return "book"
        case .savings: return "banknote"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .taxes: return "doc.text"
        case .fees: return "exclamationmark.circle"
        case .business: return "briefcase"
        case .transfer: return "arrow.left.arrow.right"
        case .gift: return "gift"
        case .charity: return "hands.sparkles"
        case .uncategorized: return "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .income: return .green
        case .housing: return .brown
        case .food: return .orange
        case .transport: return .blue
        case .health: return .pink
        case .utilities: return .yellow
        case .subscriptions: return .purple
        case .entertainment: return .indigo
        case .shopping: return .teal
        case .education: return .mint
        case .savings: return .cyan
        case .investment: return .green
        case .taxes: return .red
        case .fees: return .red
        case .business: return .blue
        case .transfer: return .gray
        case .gift: return .pink
        case .charity: return .pink
        case .uncategorized: return .secondary
        }
    }

    var isDiscretionary: Bool {
        switch self {
        case .entertainment, .shopping, .gift, .subscriptions: return true
        default: return false
        }
    }
}

enum TxSource: String, Codable, CaseIterable {
    case manual
    case bankCSV
    case rule

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .bankCSV: return "Bank import"
        case .rule: return "Auto-rule"
        }
    }
}

/// A category-assignment rule. Substring match on merchant/description → category.
/// Highest `priority` (lowest number) wins on conflict.
@Model
final class CategoryRule {
    var pattern: String
    var categoryRaw: String
    var priority: Int
    var createdAt: Date

    var category: TxCategory {
        get { TxCategory(rawValue: categoryRaw) ?? .uncategorized }
        set { categoryRaw = newValue.rawValue }
    }

    init(pattern: String, category: TxCategory, priority: Int = 50) {
        self.pattern = pattern.lowercased()
        self.categoryRaw = category.rawValue
        self.priority = priority
        self.createdAt = Date()
    }

    func matches(_ text: String) -> Bool {
        text.lowercased().contains(pattern)
    }
}

/// Seed rules — the obvious ones so a fresh import isn't 100% uncategorized.
enum DefaultCategoryRules {
    static let seeds: [(String, TxCategory)] = [
        ("netflix", .subscriptions), ("spotify", .subscriptions), ("hulu", .subscriptions),
        ("youtube", .subscriptions), ("apple.com/bill", .subscriptions), ("openai", .subscriptions),
        ("anthropic", .subscriptions), ("github", .subscriptions), ("aws", .business),
        ("digitalocean", .business), ("vercel", .business), ("cloudflare", .business),
        ("uber", .transport), ("lyft", .transport), ("shell", .transport), ("chevron", .transport),
        ("safeway", .food), ("whole foods", .food), ("trader joe", .food), ("doordash", .food),
        ("starbucks", .food), ("chipotle", .food), ("amazon", .shopping),
        ("comcast", .utilities), ("xfinity", .utilities), ("pg&e", .utilities), ("at&t", .utilities),
        ("verizon", .utilities), ("t-mobile", .utilities),
        ("rent", .housing), ("mortgage", .housing),
        ("payroll", .income), ("direct dep", .income), ("salary", .income), ("stripe payout", .income),
        ("paypal payout", .income), ("interest paid", .income),
        ("transfer to", .transfer), ("transfer from", .transfer),
        ("irs", .taxes), ("franchise tax", .taxes),
    ]
}
