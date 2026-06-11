import Foundation

struct BracketFillSlot: Identifiable {
    let id = UUID()
    let rate: Double           // 0.10, 0.12, 0.22, etc.
    let bracketTop: Decimal    // upper bound of this bracket
    let alreadyUsed: Decimal   // dollars already consuming this bracket from base income
    let headroom: Decimal      // bracketTop - alreadyUsed (clamped >= 0)
    let suggestedFill: Decimal // how much of the conversion lands here
    let taxOnFill: Decimal     // suggestedFill * rate
}

struct RothConversionPlan {
    let baseTaxableIncome: Decimal
    let conversionAmount: Decimal
    let slots: [BracketFillSlot]
    let totalTax: Decimal
    let effectiveRate: Double
    let marginalRateReached: Double
    /// "Sweet spot" recommendation: how much fills up to the next bracket without crossing.
    let recommendedFill: Decimal
    let recommendedRate: Double
}

enum RothConversionEngine {
    static func plan(
        baseTaxableIncome: Decimal,
        conversionAmount: Decimal,
        filingStatus: FilingStatus
    ) -> RothConversionPlan {
        let brackets = IncomeTaxEngine.brackets(filingStatus)
        let standardDeduction = IncomeTaxEngine.standardDeduction(filingStatus)

        let base = NSDecimalNumber(decimal: baseTaxableIncome).doubleValue
        // Base "taxable" after standard deduction. We compute the conversion on top.
        let effectiveBase = max(0, base - standardDeduction)
        let conversion = NSDecimalNumber(decimal: conversionAmount).doubleValue

        var slots: [BracketFillSlot] = []
        var remaining = conversion
        var totalTax = 0.0
        var marginalReached = 0.0

        for (idx, b) in brackets.enumerated() {
            let topOfBracket = idx + 1 < brackets.count ? brackets[idx + 1].lowerBound : .infinity
            let bracketHeadroomBeforeFill = max(0, topOfBracket - effectiveBase - (conversion - remaining))
            let alreadyUsedInBracket: Double = {
                if effectiveBase >= topOfBracket { return topOfBracket - b.lowerBound }
                if effectiveBase >= b.lowerBound { return effectiveBase - b.lowerBound }
                return 0
            }()
            let fill = min(remaining, bracketHeadroomBeforeFill)
            let tax = fill * b.rate
            totalTax += tax
            if fill > 0 { marginalReached = b.rate }
            slots.append(.init(
                rate: b.rate,
                bracketTop: topOfBracket.isFinite ? Decimal(topOfBracket) : Decimal(0),
                alreadyUsed: Decimal(alreadyUsedInBracket),
                headroom: Decimal(max(0, topOfBracket - max(effectiveBase, b.lowerBound))),
                suggestedFill: Decimal(fill),
                taxOnFill: Decimal(tax)
            ))
            remaining -= fill
            if remaining <= 0 { break }
        }

        let effectiveRate = conversion > 0 ? totalTax / conversion : 0

        // Recommended fill = amount that exactly fills to the top of the user's current marginal
        // bracket (so they convert at known rate without spilling into the next).
        let currentBracketIdx = brackets.lastIndex { effectiveBase >= $0.lowerBound } ?? 0
        let recommendedFillDouble: Double = {
            let curTop = currentBracketIdx + 1 < brackets.count
                ? brackets[currentBracketIdx + 1].lowerBound
                : effectiveBase + 100_000  // open-ended top, suggest a generous round number
            return max(0, curTop - effectiveBase)
        }()
        let recommendedRate = brackets[currentBracketIdx].rate

        return RothConversionPlan(
            baseTaxableIncome: baseTaxableIncome,
            conversionAmount: conversionAmount,
            slots: slots,
            totalTax: Decimal(totalTax),
            effectiveRate: effectiveRate,
            marginalRateReached: marginalReached,
            recommendedFill: Decimal(recommendedFillDouble),
            recommendedRate: recommendedRate
        )
    }
}
