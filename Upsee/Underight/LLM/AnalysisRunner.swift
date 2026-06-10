import Foundation

/// Orchestrates the four parallel LLM calls that produce an Analysis from a Deal.
/// Math runs synchronously first (instant); LLM calls fan out concurrently.
struct AnalysisRunner {
    let client: FoundationModelsClient

    init(client: FoundationModelsClient = FoundationModelsClient()) {
        self.client = client
    }

    func run(_ deal: Deal) async throws -> Analysis {
        // Default assumption: 100% of asking financed at the deal's SBA terms.
        let impliedLoan = LoanTerms(
            principal: deal.askingPrice,
            annualRate: deal.loanTerms.annualRate,
            amortizationYears: deal.loanTerms.amortizationYears
        )

        let normalized = SDEEngine.normalize(reportedSDE: deal.reportedSDE, addBacks: deal.addBacks)

        // DSCR honors an explicit financing stack when one was defined; otherwise it falls
        // back to the implied 100%-financed loan. The stress matrix tracks the financed
        // principal so both views agree on leverage.
        let dscr: DSCRResult
        let stressLoan: LoanTerms
        if let financing = deal.financing, !financing.loans.isEmpty {
            dscr = DSCREngine.dscr(normalizedSDE: normalized.normalized, scenario: financing)
            let financedPrincipal = financing.loans.reduce(Decimal(0)) { $0 + $1.principal }
            stressLoan = LoanTerms(
                principal: financedPrincipal > 0 ? financedPrincipal : deal.askingPrice,
                annualRate: deal.loanTerms.annualRate,
                amortizationYears: deal.loanTerms.amortizationYears
            )
        } else {
            dscr = DSCREngine.dscr(normalizedSDE: normalized.normalized, loan: impliedLoan)
            stressLoan = impliedLoan
        }

        let maxOffer = DSCREngine.maxOfferAt(
            targetDSCR: deal.targetDSCR,
            normalizedSDE: normalized.normalized,
            rate: deal.loanTerms.annualRate,
            amortizationYears: deal.loanTerms.amortizationYears
        )
        let multiple = MultipleEngine.read(
            askingPrice: deal.askingPrice,
            normalizedSDE: normalized.normalized,
            grossRevenue: deal.grossRevenue,
            category: deal.industry
        )
        let stress = SensitivityEngine.stressMatrix(
            normalizedSDE: normalized.normalized,
            loanTerms: stressLoan
        )

        async let verdictRaw: VerdictOutput = client.generate(
            systemInstructions: VoiceGuide.systemPrompt,
            prompt: PromptTemplates.verdictPrompt(
                deal: deal,
                normalized: normalized,
                dscr: dscr,
                maxOffer: maxOffer,
                multiple: multiple
            )
        )

        async let addBackReviewRaw: AddBackReviewOutput = client.generate(
            systemInstructions: VoiceGuide.systemPrompt,
            prompt: PromptTemplates.addBackReviewPrompt(deal: deal)
        )

        async let brokerQuestionsRaw: BrokerQuestionsOutput = client.generate(
            systemInstructions: VoiceGuide.systemPrompt,
            prompt: PromptTemplates.brokerQuestionsPrompt(deal: deal, normalized: normalized)
        )

        async let changeMyMindRaw: ChangeMyMindOutput = client.generate(
            systemInstructions: VoiceGuide.systemPrompt,
            prompt: PromptTemplates.changeMyMindPrompt(deal: deal, dscr: dscr, multiple: multiple)
        )

        let v = try await verdictRaw
        let abr = try await addBackReviewRaw
        let bq = try await brokerQuestionsRaw
        let cmm = try await changeMyMindRaw

        return Analysis(
            deal: deal,
            normalized: normalized,
            primaryDSCR: dscr,
            maxOffer: maxOffer,
            multipleReading: multiple,
            stress: stress,
            verdict: map(v),
            addBackReview: map(abr),
            brokerQuestions: map(bq),
            changeMyMind: map(cmm),
            generatedAt: Date()
        )
    }

    // MARK: - Output mapping

    private func map(_ v: VerdictOutput) -> Verdict {
        Verdict(
            disposition: Verdict.Disposition(rawValue: v.disposition.rawValue) ?? .marginal,
            headline: v.headline,
            oneLineSummary: v.oneLineSummary
        )
    }

    private func map(_ r: AddBackReviewOutput) -> AddBackReview {
        let items = r.items.map { item in
            AddBackComment(
                addBackID: UUID(uuidString: item.addBackID) ?? UUID(),
                label: item.label,
                verdict: AddBackVerdict(rawValue: item.verdict.rawValue) ?? .requiresVerification,
                commentary: item.commentary,
                confidence: Confidence(rawValue: item.confidence.rawValue) ?? .medium
            )
        }
        return AddBackReview(items: items, overallNote: r.overallNote)
    }

    private func map(_ q: BrokerQuestionsOutput) -> BrokerQuestions {
        let questions = q.questions.map { item in
            BrokerQuestion(
                topic: item.topic,
                question: item.question,
                why: item.why,
                confidence: Confidence(rawValue: item.confidence.rawValue) ?? .medium
            )
        }
        return BrokerQuestions(questions: questions)
    }

    private func map(_ c: ChangeMyMindOutput) -> ChangeMyMind {
        let conditions = c.conditions.map { item in
            ChangeMyMindCondition(condition: item.condition, impact: item.impact)
        }
        return ChangeMyMind(conditions: conditions)
    }
}
