import XCTest
@testable import Upsee

final class BankCSVParserTests: XCTestCase {
    func testParsesGenericFourColumnCSV() throws {
        let csv = """
        Date,Description,Amount,Account
        06/01/2026,Whole Foods,-58.23,Chase
        06/02/2026,Payroll,2500.00,Chase
        """
        let result = try BankCSVParser.parse(csv)
        XCTAssertEqual(result.transactions.count, 2)
        XCTAssertEqual(NSDecimalNumber(decimal: result.totalInflow).doubleValue, 2500, accuracy: 0.01)
        XCTAssertEqual(NSDecimalNumber(decimal: result.totalOutflow).doubleValue, 58.23, accuracy: 0.01)
    }

    func testHandlesSplitDebitCreditColumns() throws {
        let csv = """
        Date,Description,Debit,Credit
        06/01/2026,Trader Joes,42.10,
        06/02/2026,Direct Deposit,,3000.00
        """
        let result = try BankCSVParser.parse(csv)
        XCTAssertEqual(result.transactions.count, 2)
        XCTAssertEqual(NSDecimalNumber(decimal: result.totalInflow).doubleValue, 3000, accuracy: 0.01)
        XCTAssertEqual(NSDecimalNumber(decimal: result.totalOutflow).doubleValue, 42.10, accuracy: 0.01)
    }

    func testFlipsSignFromTypeColumn() throws {
        // Bank reports positive amount with "Type: Debit" → outflow.
        let csv = """
        Date,Description,Amount,Type
        06/01/2026,Spotify,9.99,Debit
        06/02/2026,Reimbursement,50.00,Credit
        """
        let result = try BankCSVParser.parse(csv)
        XCTAssertEqual(NSDecimalNumber(decimal: result.totalOutflow).doubleValue, 9.99, accuracy: 0.01)
        XCTAssertEqual(NSDecimalNumber(decimal: result.totalInflow).doubleValue, 50, accuracy: 0.01)
    }

    func testMissingDateColumnThrows() {
        let csv = "Foo,Bar\nx,y"
        XCTAssertThrowsError(try BankCSVParser.parse(csv))
    }

    func testEmptyThrows() {
        XCTAssertThrowsError(try BankCSVParser.parse(""))
    }
}
