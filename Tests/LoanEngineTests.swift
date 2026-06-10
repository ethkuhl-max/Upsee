import XCTest
@testable import Upsee

final class LoanEngineTests: XCTestCase {
    func testStandardSBALoanMonthlyPayment() {
        // $1M at 11.5% over 10 years → ~$14,061/month
        let terms = LoanTerms(principal: 1_000_000, annualRate: 0.115, amortizationYears: 10)
        let payment = NSDecimalNumber(decimal: LoanEngine.monthlyPayment(terms)).doubleValue
        XCTAssertEqual(payment, 14_061, accuracy: 50)
    }

    func testZeroPrincipalReturnsZero() {
        let terms = LoanTerms(principal: 0, annualRate: 0.10, amortizationYears: 10)
        XCTAssertEqual(LoanEngine.monthlyPayment(terms), 0)
    }

    func testZeroInterestReducesToPrincipalOverMonths() {
        let terms = LoanTerms(principal: 120_000, annualRate: 0.0, amortizationYears: 10)
        let payment = NSDecimalNumber(decimal: LoanEngine.monthlyPayment(terms)).doubleValue
        XCTAssertEqual(payment, 1_000, accuracy: 0.01)
    }

    func testAnnualDebtServiceIsTwelveMonths() {
        let terms = LoanTerms(principal: 500_000, annualRate: 0.10, amortizationYears: 10)
        let monthly = LoanEngine.monthlyPayment(terms)
        let annual = LoanEngine.annualDebtService(terms)
        XCTAssertEqual(annual, monthly * 12)
    }

    func testScenarioAggregatesAllLoans() {
        let sba = LoanTerms(principal: 700_000, annualRate: 0.115, amortizationYears: 10)
        let seller = LoanTerms(principal: 200_000, annualRate: 0.07, amortizationYears: 5)
        let scenario = FinancingScenario(label: "SBA + seller", loans: [sba, seller], buyerEquity: 100_000)

        let expected = LoanEngine.annualDebtService(sba) + LoanEngine.annualDebtService(seller)
        XCTAssertEqual(LoanEngine.annualDebtService(scenario), expected)
    }
}
