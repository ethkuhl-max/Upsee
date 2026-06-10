import Foundation

/// How much cushion sits between the deal as underwritten and the points where it
/// stops penciling — first at the lender's DSCR floor, then at true break-even.
struct BreakEven: Equatable, Codable {
    let normalizedSDE: Decimal
    let annualDebtService: Decimal

    /// SDE at which DSCR = 1.00 (debt service exactly consumes earnings).
    let breakEvenSDE: Decimal
    /// How far SDE can fall before break-even, as a fraction of current SDE (0...1).
    let sdeCushionToBreakEven: Double

    /// SDE at which DSCR = 1.25 (typical SBA underwriting floor).
    let lenderFloorSDE: Decimal
    /// How far SDE can fall before tripping the lender floor (can be negative if already below).
    let sdeCushionToLenderFloor: Double
}

enum BreakEvenEngine {
    static let lenderFloorDSCR = 1.25

    static func analyze(normalizedSDE: Decimal, loan: LoanTerms) -> BreakEven {
        analyze(normalizedSDE: normalizedSDE, annualDebtService: LoanEngine.annualDebtService(loan))
    }

    static func analyze(normalizedSDE: Decimal, scenario: FinancingScenario) -> BreakEven {
        analyze(normalizedSDE: normalizedSDE, annualDebtService: LoanEngine.annualDebtService(scenario))
    }

    private static func analyze(normalizedSDE: Decimal, annualDebtService: Decimal) -> BreakEven {
        let sde = dbl(normalizedSDE)
        let debtService = dbl(annualDebtService)

        let breakEvenSDE = debtService                       // DSCR = 1.00
        let lenderFloorSDE = debtService * lenderFloorDSCR   // DSCR = 1.25

        let cushionBreakEven = sde > 0 ? (sde - breakEvenSDE) / sde : 0
        let cushionLenderFloor = sde > 0 ? (sde - lenderFloorSDE) / sde : 0

        return BreakEven(
            normalizedSDE: normalizedSDE,
            annualDebtService: annualDebtService,
            breakEvenSDE: Decimal(breakEvenSDE),
            sdeCushionToBreakEven: cushionBreakEven,
            lenderFloorSDE: Decimal(lenderFloorSDE),
            sdeCushionToLenderFloor: cushionLenderFloor
        )
    }
}

private func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
