import XCTest
@testable import Upsee

final class ASCSalesParserTests: XCTestCase {
    func testParsesBasicTSV() throws {
        let tsv = """
        Title\tSKU\tUnits\tDeveloper Proceeds\tBegin Date
        Tmpo\ttmpo.pro\t10\t6.99\t06/01/2026
        Tmpo\ttmpo.pro\t5\t6.99\t06/02/2026
        Driver.Co\tdriver.basic\t3\t2.99\t06/01/2026
        """
        let result = try ASCSalesParser.parse(tsv)
        XCTAssertEqual(result.totalRows, 3)
        XCTAssertEqual(result.unitsByTitle["Tmpo"], 15)
        XCTAssertEqual(result.unitsByTitle["Driver.Co"], 3)
        // Tmpo: (10 + 5) * 6.99 = 104.85
        let tmpoRev = NSDecimalNumber(decimal: result.revenueByTitle["Tmpo"] ?? 0).doubleValue
        XCTAssertEqual(tmpoRev, 104.85, accuracy: 0.01)
    }

    func testMissingColumnThrows() {
        let bad = "Foo\tBar\nx\ty"
        XCTAssertThrowsError(try ASCSalesParser.parse(bad))
    }

    func testEmptyThrows() {
        XCTAssertThrowsError(try ASCSalesParser.parse(""))
    }

    func testAcceptsCSVAlternative() throws {
        let csv = """
        Title,SKU,Units,Developer Proceeds,Begin Date
        Tmpo,tmpo.pro,2,4.99,06/01/2026
        """
        let result = try ASCSalesParser.parse(csv)
        XCTAssertEqual(result.totalRows, 1)
        XCTAssertEqual(result.unitsByTitle["Tmpo"], 2)
    }
}
