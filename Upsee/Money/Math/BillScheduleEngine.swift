import Foundation

struct BillOccurrence: Identifiable {
    let id = UUID()
    let bill: Bill
    let dueDate: Date
    let amount: Decimal
    var daysFromNow: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: dueDate).day ?? 0
    }
}

struct BillCalendarSummary {
    let occurrences: [BillOccurrence]
    let monthlyCommitted: Decimal
    let dueThisWeek: [BillOccurrence]
    let overdue: [BillOccurrence]
    let upcomingMonth: [BillOccurrence]
    let upcomingQuarter: [BillOccurrence]
}

/// Projects each `Bill` forward to its next N occurrences and answers
/// "what's due soon?" queries. Pure function over the bill list.
enum BillScheduleEngine {
    static func summarize(_ bills: [Bill], horizonDays: Int = 90, now: Date = Date()) -> BillCalendarSummary {
        let active = bills.filter { $0.isActive }
        let occurrences = active.flatMap { project($0, horizonDays: horizonDays, now: now) }
            .sorted { $0.dueDate < $1.dueDate }

        let monthlyCommitted = active.reduce(Decimal(0)) { $0 + $1.monthlyEquivalent() }
        let today = Calendar.current.startOfDay(for: now)
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        let monthFromNow = Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today
        let quarterFromNow = Calendar.current.date(byAdding: .day, value: 90, to: today) ?? today

        return BillCalendarSummary(
            occurrences: occurrences,
            monthlyCommitted: monthlyCommitted,
            dueThisWeek: occurrences.filter { $0.dueDate >= today && $0.dueDate < weekFromNow },
            overdue: occurrences.filter { $0.dueDate < today },
            upcomingMonth: occurrences.filter { $0.dueDate >= today && $0.dueDate < monthFromNow },
            upcomingQuarter: occurrences.filter { $0.dueDate >= today && $0.dueDate < quarterFromNow }
        )
    }

    private static func project(_ bill: Bill, horizonDays: Int, now: Date) -> [BillOccurrence] {
        guard bill.cadence != .oneTime else {
            return [BillOccurrence(bill: bill, dueDate: bill.nextDueDate, amount: bill.amount)]
        }
        let horizonEnd = Calendar.current.date(byAdding: .day, value: horizonDays, to: now) ?? now
        var occurrences: [BillOccurrence] = []
        var current = bill.nextDueDate
        var safety = 0
        while current <= horizonEnd && safety < 30 {
            occurrences.append(.init(bill: bill, dueDate: current, amount: bill.amount))
            guard let next = Calendar.current.date(byAdding: .day, value: bill.cadence.advanceDays, to: current) else { break }
            current = next
            safety += 1
        }
        return occurrences
    }
}
