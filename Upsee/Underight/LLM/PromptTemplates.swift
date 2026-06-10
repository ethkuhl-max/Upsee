import Foundation
import FoundationModels

/// Per-section prompts + Generable output schemas. Each section is its own
/// narrow generation. Multiple narrow prompts beat one kitchen-sink prompt.
enum PromptTemplates {

    // MARK: - Deal extraction (from PDF text)

    static func dealExtractionPrompt(pdfText: String) -> String {
        """
        Extract the deal terms from the following CIM text. If a value isn't \
        clearly stated, leave it at 0 or "other".

        CIM TEXT:
        ---
        \(pdfText.prefix(20000))
        """
    }

    // MARK: - Add-back review

    static func addBackReviewPrompt(deal: Deal) -> String {
        let addBackList = deal.addBacks.map { ab in
            "- id=\(ab.id.uuidString) | \(ab.label) | $\(ab.amount) | category=\(ab.category.displayName) | seller-credibility=\(ab.credibility)"
        }.joined(separator: "\n")

        return """
        Business: \(deal.businessName) (\(deal.industry.displayName))
        Asking: $\(deal.askingPrice). Reported SDE: $\(deal.reportedSDE).

        Add-backs claimed by the seller:
        \(addBackList.isEmpty ? "(none disclosed)" : addBackList)

        For each add-back, return a verdict (accepted / discounted / rejected / requiresVerification), \
        one-line commentary in Underight voice, and a confidence (high / medium / low). \
        Cite the specific amount and category. Reference common SMB patterns where applicable.
        """
    }

    // MARK: - Verdict

    static func verdictPrompt(
        deal: Deal,
        normalized: NormalizedSDE,
        dscr: DSCRResult,
        maxOffer: Decimal,
        multiple: MultipleReading
    ) -> String {
        """
        Business: \(deal.businessName) (\(deal.industry.displayName))
        Asking: $\(deal.askingPrice)
        Reported SDE: $\(deal.reportedSDE)
        Normalized SDE (after credibility weights): $\(normalized.normalized)
        DSCR at asking (SBA \(Int(deal.loanTerms.annualRate * 100))%, \(deal.loanTerms.amortizationYears)yr): \
        \(String(format: "%.2f", dscr.value)) (\(dscr.reading.label))
        Max offer at \(String(format: "%.2f", deal.targetDSCR)) DSCR: $\(maxOffer)
        Asked multiple: \(String(format: "%.1f", multiple.askedMultiple))x vs industry median \(multiple.industryRange.median)x — \(multiple.verdict.label)

        Produce the verdict:
        - disposition: pass / marginal / worthPursuing / worthPursuingWithConditions
        - headline: ONE line — deal status, headline number, and one-clause reason
        - oneLineSummary: a short summary the reader sees at the top of the analysis

        Stay in Underight voice. Specific. Direct. No hedging.
        """
    }

    // MARK: - Broker questions

    static func brokerQuestionsPrompt(deal: Deal, normalized: NormalizedSDE) -> String {
        """
        Generate 6–10 questions to ask the broker for this deal, in priority order. \
        Each question MUST reference a specific fact about THIS deal — no generic questions. \
        Each carries a topic, the literal question, a one-line "why", and confidence.

        Business: \(deal.businessName) (\(deal.industry.displayName))
        Asking: $\(deal.askingPrice). Reported SDE: $\(deal.reportedSDE). Normalized SDE: $\(normalized.normalized).
        Add-back categories disclosed: \(deal.addBacks.map { $0.category.displayName }.joined(separator: ", "))
        """
    }

    // MARK: - Change my mind

    static func changeMyMindPrompt(deal: Deal, dscr: DSCRResult, multiple: MultipleReading) -> String {
        """
        Given the current verdict, name 2–4 specific conditions that would materially \
        change the call. Each condition is a one-line stated fact about THIS deal, plus \
        a one-line note on what changes if it's true.

        Business: \(deal.businessName) (\(deal.industry.displayName))
        Current DSCR at asking: \(String(format: "%.2f", dscr.value)) (\(dscr.reading.label))
        Current multiple verdict: \(multiple.verdict.label) (asking \(String(format: "%.1f", multiple.askedMultiple))x vs median \(multiple.industryRange.median)x)

        Be specific to this industry and this deal. Stay in voice.
        """
    }
}

// MARK: - Generable output types

@Generable
struct ExtractedDealOutput {
    @Guide(description: "Business name from the CIM")
    let businessName: String

    @Guide(description: "Industry category — pick the closest match")
    let industry: IndustryCategory

    @Guide(description: "City and state if disclosed; null otherwise")
    let location: String?

    @Guide(description: "Asking price in dollars")
    let askingPrice: Double

    @Guide(description: "Seller Discretionary Earnings (SDE) in dollars")
    let reportedSDE: Double

    @Guide(description: "Gross annual revenue in dollars; null if not disclosed")
    let grossRevenue: Double?

    @Guide(description: "Add-backs disclosed by the seller, each with label, amount, and category")
    let addBacks: [ExtractedAddBackOutput]
}

@Generable
struct ExtractedAddBackOutput {
    @Guide(description: "Short label for the add-back (e.g., 'Owner salary', 'One-time legal fees')")
    let label: String

    @Guide(description: "Dollar amount of the add-back")
    let amount: Double

    @Guide(description: "Category — pick the closest match")
    let category: AddBackCategory
}

@Generable
struct AddBackReviewOutput {
    @Guide(description: "Per-add-back skeptical commentary in Underight voice")
    let items: [AddBackCommentOutput]

    @Guide(description: "Optional one-line note about the add-back picture overall")
    let overallNote: String?
}

@Generable
struct AddBackCommentOutput {
    @Guide(description: "The UUID string for the add-back this comment refers to")
    let addBackID: String

    @Guide(description: "The add-back's label, copied")
    let label: String

    @Guide(description: "Verdict on this add-back")
    let verdict: AddBackVerdictOutput

    @Guide(description: "One-line commentary in Underight voice")
    let commentary: String

    @Guide(description: "Confidence level")
    let confidence: ConfidenceOutput
}

@Generable
enum AddBackVerdictOutput: String {
    case accepted, discounted, rejected, requiresVerification
}

@Generable
enum ConfidenceOutput: String {
    case high, medium, low
}

@Generable
struct VerdictOutput {
    @Guide(description: "Overall disposition on this deal")
    let disposition: DispositionOutput

    @Guide(description: "One-line headline — status, headline number, one-clause reason")
    let headline: String

    @Guide(description: "Short summary shown at the top of the analysis")
    let oneLineSummary: String
}

@Generable
enum DispositionOutput: String {
    case pass, marginal, worthPursuing, worthPursuingWithConditions
}

@Generable
struct BrokerQuestionsOutput {
    @Guide(description: "Prioritized list of 6–10 deal-specific broker questions")
    let questions: [BrokerQuestionOutput]
}

@Generable
struct BrokerQuestionOutput {
    @Guide(description: "Short topic label (e.g., 'Customer concentration')")
    let topic: String

    @Guide(description: "The literal question to ask the broker")
    let question: String

    @Guide(description: "One-line why this question matters")
    let why: String

    @Guide(description: "Confidence level")
    let confidence: ConfidenceOutput
}

@Generable
struct ChangeMyMindOutput {
    @Guide(description: "2–4 specific conditions that would flip the verdict")
    let conditions: [ChangeMyMindConditionOutput]
}

@Generable
struct ChangeMyMindConditionOutput {
    @Guide(description: "Specific stated fact that, if true, would change the call")
    let condition: String

    @Guide(description: "What changes if it's true")
    let impact: String
}
