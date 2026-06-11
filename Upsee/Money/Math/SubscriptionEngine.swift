import Foundation

struct DetectedSubscription: Identifiable {
    let id = UUID()
    let merchant: String
    let monthlyEquivalent: Decimal
    let cadence: SubscriptionCadence
    let occurrences: Int
    let lastChargedAt: Date
    let firstChargedAt: Date
    /// Last 12-month total committed spend.
    let annualSpend: Decimal
    /// Days since the last charge. Useful for "is this still active?"
    let daysSinceLast: Int
    /// True if the charge stopped landing — likely already cancelled, but
    /// worth surfacing so the user can confirm.
    let likelyCancelled: Bool
    /// True if amount > $50/mo or > $500/yr — worth a hard look.
    let isMaterial: Bool
    /// Most recent transaction's category (if user already categorized it).
    let userCategory: TxCategory?
}

enum SubscriptionCadence: String {
    case monthly, quarterly, annual, irregular

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .annual: return "Annual"
        case .irregular: return "Irregular"
        }
    }
}

/// Detects recurring charges from a flat transaction list. A merchant qualifies
/// as a subscription if it has ≥ 2 outflows of approximately the same amount.
enum SubscriptionEngine {
    /// Amounts within ±$1 or ±5% (whichever larger) are treated as the same
    /// recurring charge — handles ASC Apple Fee rounding and FX drift.
    static func tolerance(for amount: Decimal) -> Decimal {
        let v = NSDecimalNumber(decimal: amount).doubleValue
        let pct = abs(v) * 0.05
        return Decimal(max(1.0, pct))
    }

    static func detect(transactions: [Transaction], now: Date = Date()) -> [DetectedSubscription] {
        // Outflows only, grouped by normalized merchant.
        let outflows = transactions.filter { $0.isOutflow }
        let grouped = Dictionary(grouping: outflows) { normalize($0.merchant) }

        var subs: [DetectedSubscription] = []

        for (merchantKey, group) in grouped {
            guard group.count >= 2 else { continue }
            guard let primaryAmount = clusterPrimaryAmount(group.map { $0.absAmount }) else { continue }

            let tol = tolerance(for: primaryAmount)
            let recurring = group.filter { abs(($0.absAmount - primaryAmount).double) <= tol.double }
            guard recurring.count >= 2 else { continue }

            let sorted = recurring.sorted { $0.date < $1.date }
            guard let first = sorted.first, let last = sorted.last else { continue }
            let displayMerchant = mostCommonMerchant(sorted.map { $0.merchant }) ?? merchantKey

            let cadence = inferCadence(dates: sorted.map { $0.date })
            let monthlyEq = monthlyEquivalent(amount: primaryAmount, cadence: cadence)

            let daysSinceLast = Calendar.current.dateComponents([.day], from: last.date, to: now).day ?? 0
            let likelyCancelled = daysSinceLast > expectedGap(cadence: cadence) * 2

            let occurrencesLast12mo = sorted.filter {
                guard let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: now) else { return true }
                return $0.date >= cutoff
            }.count

            let annualSpend = primaryAmount * Decimal(occurrencesLast12mo)
            let monthlyDouble = NSDecimalNumber(decimal: monthlyEq).doubleValue
            let isMaterial = monthlyDouble >= 50 || NSDecimalNumber(decimal: annualSpend).doubleValue >= 500

            let userCategory = sorted.last?.category

            subs.append(.init(
                merchant: displayMerchant,
                monthlyEquivalent: monthlyEq,
                cadence: cadence,
                occurrences: sorted.count,
                lastChargedAt: last.date,
                firstChargedAt: first.date,
                annualSpend: annualSpend,
                daysSinceLast: daysSinceLast,
                likelyCancelled: likelyCancelled,
                isMaterial: isMaterial,
                userCategory: userCategory
            ))
        }

        return subs.sorted { $0.monthlyEquivalent > $1.monthlyEquivalent }
    }

    static func monthlyBurn(_ subscriptions: [DetectedSubscription]) -> Decimal {
        subscriptions.filter { !$0.likelyCancelled }.reduce(Decimal(0)) { $0 + $1.monthlyEquivalent }
    }

    static func zombieCandidates(_ subscriptions: [DetectedSubscription]) -> [DetectedSubscription] {
        subscriptions.filter { $0.likelyCancelled || $0.daysSinceLast > 60 }
    }

    // MARK: - Helpers

    private static func normalize(_ merchant: String) -> String {
        merchant
            .lowercased()
            .replacingOccurrences(of: "*", with: " ")
            .replacingOccurrences(of: "#", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: " ")
    }

    private static func mostCommonMerchant(_ merchants: [String]) -> String? {
        let counts = Dictionary(merchants.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }?.key
    }

    /// Pick the most common amount cluster — handles the case where the same
    /// merchant has, e.g., 9 charges of $9.99 and 2 of $19.99 (upgrade or
    /// one-off purchase): we surface the 9.99 sub.
    private static func clusterPrimaryAmount(_ amounts: [Decimal]) -> Decimal? {
        guard !amounts.isEmpty else { return nil }
        let counts = Dictionary(amounts.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }?.key
    }

    private static func inferCadence(dates: [Date]) -> SubscriptionCadence {
        guard dates.count >= 2 else { return .irregular }
        let sorted = dates.sorted()
        var gaps: [Int] = []
        for i in 1..<sorted.count {
            let d = Calendar.current.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            gaps.append(d)
        }
        let medianGap = gaps.sorted()[gaps.count / 2]
        switch medianGap {
        case 0...45: return .monthly
        case 46...120: return .quarterly
        case 121...400: return .annual
        default: return .irregular
        }
    }

    private static func expectedGap(cadence: SubscriptionCadence) -> Int {
        switch cadence {
        case .monthly: return 31
        case .quarterly: return 92
        case .annual: return 366
        case .irregular: return 60
        }
    }

    private static func monthlyEquivalent(amount: Decimal, cadence: SubscriptionCadence) -> Decimal {
        switch cadence {
        case .monthly: return amount
        case .quarterly: return amount / 3
        case .annual: return amount / 12
        case .irregular: return amount
        }
    }
}

private extension Decimal {
    var double: Double { NSDecimalNumber(decimal: self).doubleValue }
}
