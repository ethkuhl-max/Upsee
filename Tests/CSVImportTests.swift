import XCTest
@testable import Upsee

final class CSVImportTests: XCTestCase {
    func testParsesSimpleRows() {
        let rows = CSVImport.parse("name,mrr\nTmpo,1200\nWeather,300\n")
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[1], ["Tmpo", "1200"])
        XCTAssertEqual(rows[2], ["Weather", "300"])
    }

    func testHandlesQuotedFieldsWithCommas() {
        let rows = CSVImport.parse("name,summary\n\"Tmpo, Inc\",\"Tempo, simplified\"\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][0], "Tmpo, Inc")
        XCTAssertEqual(rows[1][1], "Tempo, simplified")
    }

    func testHandlesEscapedQuotes() {
        let rows = CSVImport.parse("name\n\"He said \"\"hi\"\"\"\n")
        XCTAssertEqual(rows[1][0], "He said \"hi\"")
    }

    func testSkipsBlankLines() {
        let rows = CSVImport.parse("name\nTmpo\n\n\nWeather\n")
        XCTAssertEqual(rows.count, 3)
    }
}
