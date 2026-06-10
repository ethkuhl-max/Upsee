import XCTest
@testable import Upsee

final class SensitivityGridTests: XCTestCase {
    func testGridDimensions() {
        let grid = SensitivityEngine.grid(
            normalizedSDE: 400_000,
            principal: 1_000_000,
            amortizationYears: 10,
            sdeFactors: [1.0, 0.9, 0.8],
            rates: [0.10, 0.12]
        )
        XCTAssertEqual(grid.cells.count, 3)
        XCTAssertEqual(grid.cells[0].count, 2)
    }

    func testHigherRateLowersDSCR() {
        let grid = SensitivityEngine.grid(
            normalizedSDE: 400_000,
            principal: 1_000_000,
            amortizationYears: 10,
            sdeFactors: [1.0],
            rates: [0.10, 0.15]
        )
        XCTAssertGreaterThan(grid.cells[0][0].value, grid.cells[0][1].value)
    }

    func testLowerSDELowersDSCR() {
        let grid = SensitivityEngine.grid(
            normalizedSDE: 400_000,
            principal: 1_000_000,
            amortizationYears: 10,
            sdeFactors: [1.0, 0.8],
            rates: [0.10]
        )
        XCTAssertGreaterThan(grid.cells[0][0].value, grid.cells[1][0].value)
    }
}
