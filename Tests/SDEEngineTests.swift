import XCTest
@testable import Upsee

final class SDEEngineTests: XCTestCase {
    func testNoAddBacksReturnsReportedSDE() {
        let r = SDEEngine.normalize(reportedSDE: 400_000, addBacks: [])
        XCTAssertEqual(r.normalized, 400_000)
        XCTAssertEqual(r.reported, 400_000)
        XCTAssertEqual(r.claimedAddBacks, 0)
        XCTAssertEqual(r.acceptedAddBacks, 0)
    }

    func testFullyCredibleAddBacksSurvive() {
        let addBacks = [
            AddBack(label: "Depreciation", amount: 30_000, category: .depreciation),
            AddBack(label: "Interest", amount: 25_000, category: .interest)
        ]
        let r = SDEEngine.normalize(reportedSDE: 400_000, addBacks: addBacks)
        XCTAssertEqual(r.normalized, 400_000)
        XCTAssertEqual(r.claimedAddBacks, 55_000)
        XCTAssertEqual(r.acceptedAddBacks, 55_000)
    }

    func testZeroCredibilityAddBacksGetStripped() {
        let addBacks = [
            AddBack(label: "Suspect meals", amount: 50_000, category: .personalMeals, credibility: 0.0)
        ]
        let r = SDEEngine.normalize(reportedSDE: 400_000, addBacks: addBacks)
        XCTAssertEqual(r.normalized, 350_000)
        XCTAssertEqual(r.sdeReduction, 50_000)
    }

    func testMixedCredibilityComputesWeightedSum() {
        let addBacks = [
            AddBack(label: "Owner salary", amount: 120_000, category: .ownerSalary, credibility: 1.0),
            AddBack(label: "Personal vehicle", amount: 12_000, category: .personalVehicle, credibility: 0.5),
            AddBack(label: "One-time legal", amount: 40_000, category: .oneTimeExpense, credibility: 0.25)
        ]
        let r = SDEEngine.normalize(reportedSDE: 500_000, addBacks: addBacks)
        // base = 500_000 - 172_000 = 328_000
        // accepted = 120_000 + 6_000 + 10_000 = 136_000
        // normalized = 328_000 + 136_000 = 464_000
        XCTAssertEqual(r.normalized, 464_000)
        XCTAssertEqual(r.acceptedAddBacks, 136_000)
        XCTAssertEqual(r.claimedAddBacks, 172_000)
        XCTAssertEqual(r.sdeReduction, 36_000)
    }

    func testCredibilityRatioReflectsDamage() {
        let addBacks = [
            AddBack(label: "Fake one-timer", amount: 100_000, category: .oneTimeExpense, credibility: 0.0)
        ]
        let r = SDEEngine.normalize(reportedSDE: 500_000, addBacks: addBacks)
        XCTAssertEqual(r.normalized, 400_000)
        XCTAssertEqual(r.credibilityRatio, 0.8, accuracy: 0.001)
    }

    func testCategoryDefaultCredibilityApplies() {
        let addBacks = [
            AddBack(label: "Lunches", amount: 10_000, category: .personalMeals)
        ]
        let r = SDEEngine.normalize(reportedSDE: 100_000, addBacks: addBacks)
        // personalMeals default = 0.2
        // base = 100k - 10k = 90k
        // accepted = 2k
        // normalized = 92k
        XCTAssertEqual(r.normalized, 92_000)
    }
}
