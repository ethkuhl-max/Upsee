import Foundation
import FoundationModels

/// Generates concrete adversarial scenarios — concentrated bear-case "what if X
/// happens" framings — using the Underight voice guide. The point isn't to
/// frighten; it's to surface honest concentration risks the user wouldn't write
/// themselves.
@Generable
struct AdversarialWealthOutput {
    @Guide(description: "Three adversarial bear-case scenarios specific to this portfolio. Each is concrete and quantified.")
    let scenarios: [AdversarialWealthScenario]
}

@Generable
struct AdversarialWealthScenario {
    @Guide(description: "Short scenario title — under 8 words")
    let title: String

    @Guide(description: "What specifically triggers this scenario — name the app, deal, or income source involved, and the precipitating event")
    let trigger: String

    @Guide(description: "Quantified impact on projected wealth. Cite specific dollar figures, percentages, or runway changes.")
    let impact: String

    @Guide(description: "What concrete action would mitigate this risk — one or two specific moves the user could make now")
    let mitigation: String
}

struct WealthAdversarialGenerator {
    let client: FoundationModelsClient

    init(client: FoundationModelsClient = FoundationModelsClient()) {
        self.client = client
    }

    func generate(
        apps: [AppEntity],
        jobs: [JobEntity],
        deals: [DealEntity],
        personal: PersonalEntity?,
        retirement: [RetirementAccount],
        netWorth: Decimal,
        liquidAssets: Decimal,
        concentrationFlags: [BalanceSheetCategory]
    ) async throws -> AdversarialWealthOutput {
        let context = formatContext(
            apps: apps,
            jobs: jobs,
            deals: deals,
            personal: personal,
            retirement: retirement,
            netWorth: netWorth,
            liquidAssets: liquidAssets,
            concentrationFlags: concentrationFlags
        )
        return try await client.generate(
            systemInstructions: VoiceGuide.systemPrompt,
            prompt: prompt(context: context)
        )
    }

    private func prompt(context: String) -> String {
        """
        Generate three adversarial bear-case scenarios for this operator's wealth picture. \
        The point is to be honest about concentration risk and tail outcomes the operator \
        wouldn't write for themselves. Stay in Underight voice — skeptical, specific, \
        pattern-recognizing. Cite specific dollar figures from the state. No generic \
        warnings ("market crash"). Each scenario must name a specific app / deal / income \
        source and a precipitating event tied to it.

        STATE
        ---
        \(context)
        ---
        """
    }

    private func formatContext(
        apps: [AppEntity],
        jobs: [JobEntity],
        deals: [DealEntity],
        personal: PersonalEntity?,
        retirement: [RetirementAccount],
        netWorth: Decimal,
        liquidAssets: Decimal,
        concentrationFlags: [BalanceSheetCategory]
    ) -> String {
        var lines: [String] = []
        lines.append("Net worth: \(currency(netWorth))")
        lines.append("Liquid assets: \(currency(liquidAssets))")
        if !concentrationFlags.isEmpty {
            let flags = concentrationFlags.map { $0.displayName }.joined(separator: ", ")
            lines.append("Concentration flags: \(flags)")
        }

        if !apps.isEmpty {
            lines.append("")
            lines.append("APPS:")
            for app in apps {
                var parts = ["• \(app.name) [\(app.status.displayName)]"]
                if app.monthlyRevenue > 0 { parts.append("MRR \(currency(app.monthlyRevenue))") }
                if app.activeUsers > 0 { parts.append("\(app.activeUsers) users") }
                if !app.summary.isEmpty { parts.append("\"\(app.summary)\"") }
                lines.append(parts.joined(separator: " | "))
            }
        }

        if !jobs.isEmpty {
            lines.append("")
            lines.append("JOBS:")
            for job in jobs {
                lines.append("• \(job.title) @ \(job.employer) [\(job.status.displayName)] | \(currency(job.monthlyCompensation))/mo")
            }
        }

        if !deals.isEmpty {
            lines.append("")
            lines.append("DEALS:")
            for deal in deals {
                lines.append("• \(deal.businessName) [\(deal.status.displayName)] | asking \(currency(deal.askingPrice))")
            }
        }

        if let p = personal {
            lines.append("")
            lines.append("PERSONAL: Income \(currency(p.monthlyIncome))/mo | Expenses \(currency(p.monthlyExpenses))/mo | Savings \(currency(p.currentSavings))")
        }

        if !retirement.isEmpty {
            lines.append("")
            lines.append("RETIREMENT:")
            for r in retirement {
                lines.append("• \(r.name) [\(r.kind.displayName)] | \(currency(r.currentBalance)) balance | \(currency(r.contributionsYTD)) YTD contributions")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func currency(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        f.currencyCode = "USD"
        return f.string(from: NSDecimalNumber(decimal: d)) ?? "$0"
    }
}
