import Foundation

/// Renders an `Analysis` as a clean Markdown document for export and sharing.
enum AnalysisMarkdown {
    static func render(_ analysis: Analysis) -> String {
        var out: [String] = []
        let deal = analysis.deal

        out.append("# \(deal.businessName) — Underight Analysis")
        out.append("**\(disposition(analysis.verdict.disposition))** · \(deal.industry.displayName)")
        out.append("")
        out.append("> \(analysis.verdict.headline)")
        out.append("")
        out.append(analysis.verdict.oneLineSummary)
        out.append("")

        out.append("## The numbers")
        out.append("- **Asking price:** \(money(deal.askingPrice))")
        out.append("- **Reported SDE:** \(money(deal.reportedSDE))")
        var normLine = "- **Normalized SDE:** \(money(analysis.normalized.normalized))"
        if analysis.normalized.sdeReduction > 0 {
            normLine += " (−\(money(analysis.normalized.sdeReduction)) after credibility weighting)"
        }
        out.append(normLine)
        out.append("- **Asked multiple:** \(String(format: "%.2fx", analysis.multipleReading.askedMultiple)) — \(analysis.multipleReading.verdict.label)")
        out.append("- **DSCR at asking:** \(String(format: "%.2f", analysis.primaryDSCR.value)) — \(analysis.primaryDSCR.reading.label)")
        out.append("- **Max offer at \(String(format: "%.2f", deal.targetDSCR)) DSCR:** \(money(analysis.maxOffer))")
        out.append("")

        if !analysis.stress.isEmpty {
            out.append("### Stress matrix")
            for row in analysis.stress {
                out.append("- \(row.label): \(String(format: "%.2f", row.dscr.value)) (\(row.dscr.reading.label))")
            }
            out.append("")
        }

        out.append("## Skeptical review of the add-backs")
        if analysis.addBackReview.items.isEmpty {
            out.append("_No add-backs disclosed in the CIM._")
        } else {
            for item in analysis.addBackReview.items {
                out.append("- **\(addBackVerdict(item.verdict))** \(item.label) — \(item.commentary) _(\(item.confidence.rawValue) confidence)_")
            }
            if let note = analysis.addBackReview.overallNote, !note.isEmpty {
                out.append("")
                out.append("_\(note)_")
            }
        }
        out.append("")

        out.append("## Questions for the broker")
        if analysis.brokerQuestions.questions.isEmpty {
            out.append("_None produced._")
        } else {
            for (i, q) in analysis.brokerQuestions.questions.enumerated() {
                out.append("\(i + 1). **[\(q.topic)]** \(q.question)")
                out.append("   - _Why:_ \(q.why)")
            }
        }
        out.append("")

        out.append("## What would change this call")
        if analysis.changeMyMind.conditions.isEmpty {
            out.append("_Nothing on the table that would flip the verdict._")
        } else {
            for c in analysis.changeMyMind.conditions {
                out.append("- **\(c.condition)** — \(c.impact)")
            }
        }
        out.append("")

        out.append("---")
        out.append("_Generated \(longDate(analysis.generatedAt)) · Upsee / Underight (on-device analysis, not investment advice)_")

        return out.joined(separator: "\n")
    }

    // MARK: - Formatting

    private static func disposition(_ d: Verdict.Disposition) -> String {
        switch d {
        case .pass: return "PASS"
        case .marginal: return "MARGINAL"
        case .worthPursuing: return "WORTH PURSUING"
        case .worthPursuingWithConditions: return "WORTH PURSUING — WITH CONDITIONS"
        }
    }

    private static func addBackVerdict(_ v: AddBackVerdict) -> String {
        switch v {
        case .accepted: return "ACCEPTED"
        case .discounted: return "DISCOUNTED"
        case .rejected: return "REJECTED"
        case .requiresVerification: return "VERIFY"
        }
    }

    private static func money(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencyCode = "USD"
        return f.string(from: NSDecimalNumber(decimal: d)) ?? "$0"
    }

    private static func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: date)
    }
}
