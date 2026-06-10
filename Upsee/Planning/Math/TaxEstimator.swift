import Foundation

/// Quarterly estimated-tax due dates. The income tax math itself lives in `IncomeTaxEngine`.
enum TaxEstimator {
    /// IRS quarterly estimated tax due dates: Apr 15, Jun 15, Sep 15, Jan 15.
    static func nextQuarterlyDueDate(from now: Date) -> Date? {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: now)
        let candidates: [DateComponents] = [
            DateComponents(year: year, month: 4, day: 15),
            DateComponents(year: year, month: 6, day: 15),
            DateComponents(year: year, month: 9, day: 15),
            DateComponents(year: year + 1, month: 1, day: 15),
        ]
        for comp in candidates {
            if let date = cal.date(from: comp), date >= now {
                return date
            }
        }
        return cal.date(from: DateComponents(year: year + 1, month: 4, day: 15))
    }

    static func dueDate(forYear year: Int, quarter: Int) -> Date? {
        let cal = Calendar(identifier: .gregorian)
        switch quarter {
        case 1: return cal.date(from: DateComponents(year: year, month: 4, day: 15))
        case 2: return cal.date(from: DateComponents(year: year, month: 6, day: 15))
        case 3: return cal.date(from: DateComponents(year: year, month: 9, day: 15))
        case 4: return cal.date(from: DateComponents(year: year + 1, month: 1, day: 15))
        default: return nil
        }
    }
}
