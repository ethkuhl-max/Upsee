import Foundation

/// Turns extracted PDF text into a `Deal` candidate via an on-device LLM call.
/// The user reviews/corrects the result in `DealCardView` before analysis.
struct DealExtractor {
    let client: FoundationModelsClient

    init(client: FoundationModelsClient = FoundationModelsClient()) {
        self.client = client
    }

    func extract(from extracted: PDFExtractor.ExtractedText, sourcePDFPath: String? = nil) async throws -> Deal {
        let payload: ExtractedDealOutput = try await client.generate(
            systemInstructions: VoiceGuide.systemPrompt,
            prompt: PromptTemplates.dealExtractionPrompt(pdfText: extracted.combined)
        )
        return mapToDeal(payload, sourcePDFPath: sourcePDFPath)
    }

    private func mapToDeal(_ payload: ExtractedDealOutput, sourcePDFPath: String?) -> Deal {
        let addBacks: [AddBack] = payload.addBacks.map { extracted in
            AddBack(
                label: extracted.label,
                amount: Decimal(extracted.amount),
                category: extracted.category
            )
        }
        return Deal(
            businessName: payload.businessName,
            industry: payload.industry,
            location: payload.location,
            askingPrice: Decimal(payload.askingPrice),
            reportedSDE: Decimal(payload.reportedSDE),
            grossRevenue: payload.grossRevenue.map { Decimal($0) },
            addBacks: addBacks,
            loanTerms: .sbaDefault,
            targetDSCR: 1.25,
            sourcePDFPath: sourcePDFPath
        )
    }
}
