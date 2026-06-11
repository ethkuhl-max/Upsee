import Foundation

/// Decoupled client input so the engine is testable without SwiftData.
struct ClientBookInput {
    let name: String
    let aum: Decimal
    let feePercent: Double
    let status: ClientStatus
    let nextReviewDate: Date?
}

struct ReviewDue: Equatable {
    let name: String
    let date: Date
    let isOverdue: Bool
}

struct BookSummary: Equatable {
    let totalAUM: Decimal
    let annualRevenue: Decimal
    let activeCount: Int
    let prospectCount: Int
    let inactiveCount: Int
    let weightedAverageFee: Double    // revenue ÷ AUM
    let upcomingReviews: [ReviewDue]
}

/// Rolls up the advisor's book: AUM, fee revenue, client mix, and review pipeline.
enum BookOfBusinessEngine {
    static func summarize(_ clients: [ClientBookInput], asOf today: Date, withinDays: Int = 60) -> BookSummary {
        let totalAUM = clients.reduce(Decimal(0)) { $0 + $1.aum }
        let revenue = clients.reduce(Decimal(0)) { $0 + $1.aum * Decimal($1.feePercent) }

        let active = clients.filter { $0.status == .active }.count
        let prospects = clients.filter { $0.status == .prospect }.count
        let inactive = clients.filter { $0.status == .inactive }.count

        let aumD = dbl(totalAUM)
        let weightedFee = aumD > 0 ? dbl(revenue) / aumD : 0

        let horizon = Calendar.current.date(byAdding: .day, value: withinDays, to: today) ?? today
        let reviews = clients.compactMap { c -> ReviewDue? in
            guard c.status != .inactive, let date = c.nextReviewDate else { return nil }
            guard date <= horizon else { return nil }   // overdue or due within the window
            return ReviewDue(name: c.name, date: date, isOverdue: date < today)
        }.sorted { $0.date < $1.date }

        return BookSummary(
            totalAUM: totalAUM,
            annualRevenue: revenue,
            activeCount: active,
            prospectCount: prospects,
            inactiveCount: inactive,
            weightedAverageFee: weightedFee,
            upcomingReviews: reviews
        )
    }

    private static func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}
