import Foundation

/// Parsed row from an App Store Connect Sales and Trends report.
/// Apple's TSV columns are stable; we pull the four we care about.
struct ASCSalesRow {
    let title: String
    let sku: String
    let units: Int
    let proceeds: Decimal
    let beginDate: Date
}

struct ASCImportResult {
    /// App title → summed proceeds across all matching rows in this file.
    let revenueByTitle: [String: Decimal]
    /// App title → summed unit downloads.
    let unitsByTitle: [String: Int]
    let totalRows: Int
    let earliestDate: Date?
    let latestDate: Date?

    var totalProceeds: Decimal {
        revenueByTitle.values.reduce(Decimal(0), +)
    }

    var totalUnits: Int {
        unitsByTitle.values.reduce(0, +)
    }
}

/// Parses Apple's Sales and Trends report (tab-separated, headers in row 1).
/// Spec: https://developer.apple.com/help/app-store-connect/reference/financial-report-format
enum ASCSalesParser {
    /// Required headers — anything else in the file we ignore. Each is matched
    /// case-insensitively and tolerates minor wording drift across Apple's
    /// report versions.
    private static let titleHeaders = ["title"]
    private static let skuHeaders = ["sku", "apple identifier"]
    private static let unitsHeaders = ["units"]
    private static let proceedsHeaders = ["developer proceeds", "amount (developer proceeds)"]
    private static let beginDateHeaders = ["begin date", "begin_date"]

    static func parse(_ text: String) throws -> ASCImportResult {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { throw ASCImportError.empty }

        let separator: Character = lines[0].contains("\t") ? "\t" : ","
        let header = lines[0].split(separator: separator).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        guard let titleIdx = indexOf(header, anyOf: titleHeaders) else { throw ASCImportError.missingColumn("Title") }
        guard let unitsIdx = indexOf(header, anyOf: unitsHeaders) else { throw ASCImportError.missingColumn("Units") }
        guard let proceedsIdx = indexOf(header, anyOf: proceedsHeaders) else { throw ASCImportError.missingColumn("Developer Proceeds") }
        guard let beginIdx = indexOf(header, anyOf: beginDateHeaders) else { throw ASCImportError.missingColumn("Begin Date") }
        let skuIdx = indexOf(header, anyOf: skuHeaders)

        var revenueByTitle: [String: Decimal] = [:]
        var unitsByTitle: [String: Int] = [:]
        var dates: [Date] = []
        var rowCount = 0

        for line in lines.dropFirst() {
            let cols = line.split(separator: separator, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count > max(titleIdx, unitsIdx, proceedsIdx, beginIdx) else { continue }
            let title = cols[titleIdx]
            if title.isEmpty { continue }
            let units = Int(cols[unitsIdx]) ?? 0
            let proceeds = Decimal(string: cols[proceedsIdx].replacingOccurrences(of: ",", with: "")) ?? 0
            // Per-unit proceeds × units = row total. ASC reports per-unit by default.
            let rowProceeds = proceeds * Decimal(units)
            revenueByTitle[title, default: 0] += rowProceeds
            unitsByTitle[title, default: 0] += units
            if let date = parseDate(cols[beginIdx]) {
                dates.append(date)
            }
            rowCount += 1
            _ = skuIdx // present for future per-SKU breakdowns
        }

        return ASCImportResult(
            revenueByTitle: revenueByTitle,
            unitsByTitle: unitsByTitle,
            totalRows: rowCount,
            earliestDate: dates.min(),
            latestDate: dates.max()
        )
    }

    private static func indexOf(_ header: [String], anyOf candidates: [String]) -> Int? {
        for candidate in candidates {
            if let idx = header.firstIndex(of: candidate) { return idx }
        }
        return nil
    }

    private static func parseDate(_ s: String) -> Date? {
        // Apple uses MM/DD/YYYY in Sales reports.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Los_Angeles")
        f.dateFormat = "MM/dd/yyyy"
        if let d = f.date(from: s) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}

enum ASCImportError: LocalizedError {
    case empty
    case missingColumn(String)

    var errorDescription: String? {
        switch self {
        case .empty: return "The file is empty or unreadable."
        case .missingColumn(let name): return "Required column missing: \(name). Make sure you downloaded the Sales and Trends report."
        }
    }
}
