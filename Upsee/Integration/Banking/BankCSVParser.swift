import Foundation

struct BankParsedTransaction {
    let date: Date
    let amount: Decimal
    let merchant: String
    let rawDescription: String
}

struct BankImportResult {
    let transactions: [BankParsedTransaction]
    let totalInflow: Decimal
    let totalOutflow: Decimal
    let earliestDate: Date?
    let latestDate: Date?
    let detectedFormat: String
}

/// Parses bank/credit CSV exports. No single standard exists — we sniff the
/// header to figure out which columns are which. Supports common forms:
/// - Generic 4-col: Date, Description, Amount, [Account]
/// - Chase: Posting Date, Description, Amount, Type
/// - Amex: Date, Description, Amount (negative = charge)
/// - Mint export: Date, Description, Amount, Transaction Type, Category, ...
enum BankCSVParser {
    static func parse(_ text: String) throws -> BankImportResult {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { throw BankImportError.empty }

        let separator: Character = lines[0].contains("\t") ? "\t" : ","
        let header = lines[0]
            .split(separator: separator, omittingEmptySubsequences: false)
            .map { sanitize(String($0)).lowercased() }

        guard let dateIdx = indexOf(header, anyOf: ["date", "posting date", "transaction date", "trans date"])
        else { throw BankImportError.missingColumn("Date") }
        guard let descIdx = indexOf(header, anyOf: ["description", "merchant", "name", "payee", "details"])
        else { throw BankImportError.missingColumn("Description") }
        // Amount can be split across debit/credit columns or in one signed amount column.
        let amountIdx = indexOf(header, anyOf: ["amount", "amount (usd)", "transaction amount"])
        let debitIdx = indexOf(header, anyOf: ["debit", "withdrawal", "withdrawals", "money out"])
        let creditIdx = indexOf(header, anyOf: ["credit", "deposit", "deposits", "money in"])
        if amountIdx == nil && debitIdx == nil && creditIdx == nil {
            throw BankImportError.missingColumn("Amount / Debit / Credit")
        }
        let txTypeIdx = indexOf(header, anyOf: ["transaction type", "type"])

        let format = detectedFormat(headers: header)
        var transactions: [BankParsedTransaction] = []
        var inflow: Decimal = 0
        var outflow: Decimal = 0
        var dates: [Date] = []

        for line in lines.dropFirst() {
            let cols = splitCSVLine(line, separator: separator)
            guard cols.count > max(dateIdx, descIdx) else { continue }
            guard let date = parseDate(cols[dateIdx]) else { continue }
            let description = sanitize(cols[descIdx])
            let amount = parseSignedAmount(
                cols: cols,
                amountIdx: amountIdx,
                debitIdx: debitIdx,
                creditIdx: creditIdx,
                txTypeIdx: txTypeIdx
            )
            if amount == 0 { continue }
            transactions.append(.init(
                date: date,
                amount: amount,
                merchant: cleanMerchant(description),
                rawDescription: description
            ))
            if amount > 0 { inflow += amount } else { outflow += -amount }
            dates.append(date)
        }

        return BankImportResult(
            transactions: transactions,
            totalInflow: inflow,
            totalOutflow: outflow,
            earliestDate: dates.min(),
            latestDate: dates.max(),
            detectedFormat: format
        )
    }

    // MARK: - Sniffing & helpers

    private static func detectedFormat(headers: [String]) -> String {
        if headers.contains("posting date") { return "Chase" }
        if headers.contains("transaction type") && headers.contains("category") { return "Mint export" }
        if headers.contains("debit") || headers.contains("credit") { return "Split debit/credit" }
        return "Generic"
    }

    private static func indexOf(_ header: [String], anyOf candidates: [String]) -> Int? {
        for c in candidates {
            if let idx = header.firstIndex(of: c) { return idx }
        }
        return nil
    }

    private static func sanitize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
    }

    private static func parseSignedAmount(
        cols: [String],
        amountIdx: Int?,
        debitIdx: Int?,
        creditIdx: Int?,
        txTypeIdx: Int?
    ) -> Decimal {
        // Prefer signed amount if present.
        if let amountIdx, cols.count > amountIdx {
            let raw = cols[amountIdx].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            let value = Decimal(string: raw) ?? 0
            // Some banks pair "amount" (always positive) with a Type column.
            if let txTypeIdx, cols.count > txTypeIdx {
                let t = cols[txTypeIdx].lowercased()
                if value > 0 && (t.contains("debit") || t.contains("withdraw") || t.contains("payment") || t.contains("purchase")) {
                    return -value
                }
            }
            return value
        }
        // Split debit/credit columns.
        var amount: Decimal = 0
        if let debitIdx, cols.count > debitIdx {
            let raw = cols[debitIdx].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            if !raw.isEmpty, let v = Decimal(string: raw), v != 0 {
                amount = -v
            }
        }
        if let creditIdx, cols.count > creditIdx {
            let raw = cols[creditIdx].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            if !raw.isEmpty, let v = Decimal(string: raw), v != 0 {
                amount = v
            }
        }
        return amount
    }

    private static func parseDate(_ s: String) -> Date? {
        let cleaned = sanitize(s)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd", "MM/dd/yy", "M/d/yy"] {
            f.dateFormat = fmt
            if let d = f.date(from: cleaned) { return d }
        }
        return nil
    }

    /// Strip the noise banks add: trailing tx IDs, geo codes, store numbers.
    private static func cleanMerchant(_ s: String) -> String {
        var result = s
        // Remove trailing # / store numbers.
        result = result.replacingOccurrences(of: #"\s+#\d+.*$"#, with: "", options: .regularExpression)
        // Remove trailing city/state codes like "  CA US".
        result = result.replacingOccurrences(of: #"\s+[A-Z]{2}\s+[A-Z]{2}$"#, with: "", options: .regularExpression)
        // Collapse whitespace.
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// CSV-aware line split: respects quoted fields with embedded commas.
    private static func splitCSVLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == separator && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }
}

enum BankImportError: LocalizedError {
    case empty
    case missingColumn(String)

    var errorDescription: String? {
        switch self {
        case .empty: return "File is empty or unreadable."
        case .missingColumn(let name): return "Required column missing: \(name)."
        }
    }
}
