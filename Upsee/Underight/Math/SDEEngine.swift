import Foundation

/// Normalizes the seller's reported SDE by applying per-add-back credibility weights.
///
/// Sellers stack add-backs to push reported SDE upward and justify the asking multiple.
/// Underight's job is to apply skeptical weights — the result is the SDE a buyer should
/// actually underwrite against.
struct NormalizedSDE: Codable, Equatable {
    /// What the seller claimed.
    let reported: Decimal
    /// The earnings number before any add-backs.
    let baseEarnings: Decimal
    /// Sum of add-back amounts the seller submitted.
    let claimedAddBacks: Decimal
    /// Sum of add-back amounts after credibility weighting.
    let acceptedAddBacks: Decimal
    /// What Underight thinks the real SDE is.
    let normalized: Decimal
    /// `normalized / reported`, useful for one-line communication.
    let credibilityRatio: Double

    /// How much SDE Underight challenged. Positive = the seller is inflating.
    var sdeReduction: Decimal { reported - normalized }
}

enum SDEEngine {
    /// Normalize a seller's stated SDE using the credibility weights on each add-back.
    static func normalize(reportedSDE: Decimal, addBacks: [AddBack]) -> NormalizedSDE {
        let claimed = addBacks.reduce(Decimal(0)) { $0 + $1.amount }
        let accepted = addBacks.reduce(Decimal(0)) { partial, addBack in
            let weight = Decimal(max(0.0, min(1.0, addBack.credibility)))
            return partial + (addBack.amount * weight)
        }
        let base = reportedSDE - claimed
        let normalized = base + accepted

        let reportedDouble = NSDecimalNumber(decimal: reportedSDE).doubleValue
        let normalizedDouble = NSDecimalNumber(decimal: normalized).doubleValue
        let ratio = reportedDouble > 0 ? normalizedDouble / reportedDouble : 1.0

        return NormalizedSDE(
            reported: reportedSDE,
            baseEarnings: base,
            claimedAddBacks: claimed,
            acceptedAddBacks: accepted,
            normalized: normalized,
            credibilityRatio: ratio
        )
    }
}
