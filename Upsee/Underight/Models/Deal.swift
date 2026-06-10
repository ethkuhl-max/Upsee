import Foundation

/// A deal under evaluation. Encodable for `.underight` document persistence.
struct Deal: Codable, Equatable {
    var id: UUID
    var businessName: String
    var industry: IndustryCategory
    var location: String?
    var askingPrice: Decimal
    var reportedSDE: Decimal
    var grossRevenue: Decimal?
    var addBacks: [AddBack]
    var loanTerms: LoanTerms
    /// Optional explicit financing stack (e.g. SBA + seller note + buyer equity). When set,
    /// it overrides the implicit "100% of asking financed at `loanTerms`" assumption for DSCR.
    var financing: FinancingScenario?
    var targetDSCR: Double
    var sourcePDFPath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        businessName: String = "Untitled Deal",
        industry: IndustryCategory = .other,
        location: String? = nil,
        askingPrice: Decimal = 0,
        reportedSDE: Decimal = 0,
        grossRevenue: Decimal? = nil,
        addBacks: [AddBack] = [],
        loanTerms: LoanTerms = .sbaDefault,
        financing: FinancingScenario? = nil,
        targetDSCR: Double = 1.25,
        sourcePDFPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.businessName = businessName
        self.industry = industry
        self.location = location
        self.askingPrice = askingPrice
        self.reportedSDE = reportedSDE
        self.grossRevenue = grossRevenue
        self.addBacks = addBacks
        self.loanTerms = loanTerms
        self.financing = financing
        self.targetDSCR = targetDSCR
        self.sourcePDFPath = sourcePDFPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
