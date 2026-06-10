import Foundation
import SwiftData

/// Imports a portfolio of apps from a CSV. Recognized (case-insensitive) headers:
/// name/app, mrr/revenue, users, summary. Header row required; column order is flexible.
enum CSVImport {
    @MainActor
    @discardableResult
    static func importApps(from data: Data, into context: ModelContext) -> Int {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return 0 }
        let rows = parse(text)
        guard let header = rows.first else { return 0 }

        let cols = header.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        func index(_ names: [String]) -> Int? { cols.firstIndex { names.contains($0) } }

        guard let nameIdx = index(["name", "app", "app name"]) else { return 0 }
        let revIdx = index(["mrr", "revenue", "monthly revenue", "monthlyrevenue"])
        let usersIdx = index(["users", "active users", "activeusers"])
        let summaryIdx = index(["summary", "description"])

        var added = 0
        for row in rows.dropFirst() {
            guard row.indices.contains(nameIdx) else { continue }
            let name = row[nameIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            let app = AppEntity(
                name: name,
                summary: field(row, summaryIdx) ?? "",
                monthlyRevenue: parseDecimal(field(row, revIdx) ?? "0"),
                activeUsers: Int(field(row, usersIdx)?.filter { $0.isNumber } ?? "") ?? 0
            )
            context.insert(app)
            added += 1
        }
        if added > 0 { try? context.save() }
        return added
    }

    private static func field(_ row: [String], _ index: Int?) -> String? {
        guard let index, row.indices.contains(index) else { return nil }
        return row[index].trimmingCharacters(in: .whitespaces)
    }

    private static func parseDecimal(_ s: String) -> Decimal {
        let cleaned = s.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }

    /// Minimal RFC-4180-ish parser: handles quoted fields, escaped quotes, and CRLF.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        let scalars = Array(text)
        var i = 0

        func endField() { record.append(field); field = "" }
        func endRecord() {
            endField()
            if record.contains(where: { !$0.isEmpty }) { rows.append(record) }
            record = []
        }

        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count && scalars[i + 1] == "\"" {
                        field.append("\""); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": endField()
                case "\n": endRecord()
                case "\r": break
                default: field.append(c)
                }
            }
            i += 1
        }
        endRecord()
        return rows
    }
}
