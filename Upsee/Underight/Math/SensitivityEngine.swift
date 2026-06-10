import Foundation

/// Stress-tests a deal against the failure modes Underight cares about most:
/// revenue declines, rate increases, and add-back compression.
struct SensitivityRow: Codable, Equatable {
    let label: String
    let normalizedSDE: Decimal
    let dscr: DSCRResult
}

enum SensitivityEngine {
    /// Returns a small grid of scenarios users can scan to see where the deal breaks.
    /// Inputs are intentionally minimal — the engine builds the standard 4-row stress
    /// matrix every analysis includes.
    static func stressMatrix(
        normalizedSDE: Decimal,
        loanTerms: LoanTerms
    ) -> [SensitivityRow] {
        let base = DSCREngine.dscr(normalizedSDE: normalizedSDE, loan: loanTerms)
        let baseRow = SensitivityRow(label: "Base case", normalizedSDE: normalizedSDE, dscr: base)

        let down10 = scale(normalizedSDE, by: 0.90)
        let down20 = scale(normalizedSDE, by: 0.80)
        let down10Row = SensitivityRow(
            label: "Revenue −10%",
            normalizedSDE: down10,
            dscr: DSCREngine.dscr(normalizedSDE: down10, loan: loanTerms)
        )
        let down20Row = SensitivityRow(
            label: "Revenue −20%",
            normalizedSDE: down20,
            dscr: DSCREngine.dscr(normalizedSDE: down20, loan: loanTerms)
        )

        var bumped = loanTerms
        bumped.annualRate += 0.01
        let rateUpRow = SensitivityRow(
            label: "Rate +100 bps",
            normalizedSDE: normalizedSDE,
            dscr: DSCREngine.dscr(normalizedSDE: normalizedSDE, loan: bumped)
        )

        return [baseRow, down10Row, down20Row, rateUpRow]
    }

    /// A two-variable DSCR grid: SDE haircut down the rows, interest rate across the columns.
    /// Lets a buyer read the whole failure surface at once rather than four discrete rows.
    static func grid(
        normalizedSDE: Decimal,
        principal: Decimal,
        amortizationYears: Int,
        sdeFactors: [Double] = [1.10, 1.00, 0.90, 0.80, 0.70],
        rates: [Double] = [0.09, 0.11, 0.13, 0.15]
    ) -> SensitivityGrid {
        let cells = sdeFactors.map { factor -> [DSCRResult] in
            let stressedSDE = scale(normalizedSDE, by: factor)
            return rates.map { rate in
                let loan = LoanTerms(principal: principal, annualRate: rate, amortizationYears: amortizationYears)
                return DSCREngine.dscr(normalizedSDE: stressedSDE, loan: loan)
            }
        }
        return SensitivityGrid(sdeFactors: sdeFactors, rates: rates, cells: cells)
    }

    private static func scale(_ value: Decimal, by factor: Double) -> Decimal {
        let d = NSDecimalNumber(decimal: value).doubleValue
        return Decimal(d * factor)
    }
}

/// Result of `SensitivityEngine.grid` — `cells[row][col]` aligns with `sdeFactors[row]` and `rates[col]`.
struct SensitivityGrid: Equatable, Codable {
    let sdeFactors: [Double]
    let rates: [Double]
    let cells: [[DSCRResult]]
}
