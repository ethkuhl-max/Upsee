import Foundation
import SwiftData
import SwiftUI

@Model
final class DealEntity {
    /// Mirrors the in-memory `Deal.id`, used to upsert a deal after re-analysis.
    var dealID: UUID = UUID()
    var businessName: String
    var industryRaw: String
    var location: String?
    var askingPrice: Decimal
    var reportedSDE: Decimal
    var lastVerdictLabel: String
    var lastVerdictHeadline: String
    var statusRaw: String
    var sourcePDFPath: String?
    var note: String
    var followUpDate: Date?
    var lastAnalyzedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    /// JSON-encoded `Analysis` — the full saved underwriting, so the report can be reopened.
    var analysisData: Data?

    var status: DealStatus {
        get { DealStatus(rawValue: statusRaw) ?? .watching }
        set { statusRaw = newValue.rawValue }
    }

    var industry: IndustryCategory {
        IndustryCategory(rawValue: industryRaw) ?? .other
    }

    /// The full saved analysis, decoded on demand. Nil if this deal was never analyzed.
    var savedAnalysis: Analysis? {
        guard let analysisData else { return nil }
        return try? JSONDecoder().decode(Analysis.self, from: analysisData)
    }

    init(
        businessName: String,
        industryRaw: String = "other",
        askingPrice: Decimal = 0,
        reportedSDE: Decimal = 0,
        status: DealStatus = .watching
    ) {
        self.dealID = UUID()
        self.businessName = businessName
        self.industryRaw = industryRaw
        self.location = nil
        self.askingPrice = askingPrice
        self.reportedSDE = reportedSDE
        self.lastVerdictLabel = ""
        self.lastVerdictHeadline = ""
        self.statusRaw = status.rawValue
        self.sourcePDFPath = nil
        self.note = ""
        self.followUpDate = nil
        self.lastAnalyzedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.analysisData = nil
    }

    /// Populate this entity from a freshly produced analysis. Preserves the user's
    /// pipeline `status` (saving an analysis shouldn't reset where the deal sits).
    func apply(_ analysis: Analysis) {
        let deal = analysis.deal
        dealID = deal.id
        businessName = deal.businessName
        industryRaw = deal.industry.rawValue
        location = deal.location
        askingPrice = deal.askingPrice
        reportedSDE = deal.reportedSDE
        lastVerdictLabel = analysis.verdict.disposition.rawValue
        lastVerdictHeadline = analysis.verdict.headline
        sourcePDFPath = deal.sourcePDFPath
        lastAnalyzedAt = analysis.generatedAt
        analysisData = try? JSONEncoder().encode(analysis)
        updatedAt = Date()
    }
}

enum DealStatus: String, Codable, CaseIterable {
    case watching
    case passed
    case loi
    case dueDiligence
    case closed
    case dead

    var displayName: String {
        switch self {
        case .watching: return "Watching"
        case .passed: return "Passed"
        case .loi: return "LOI Signed"
        case .dueDiligence: return "In Diligence"
        case .closed: return "Closed"
        case .dead: return "Dead"
        }
    }

    var tint: Color {
        switch self {
        case .watching: return .blue
        case .passed: return .gray
        case .loi: return .yellow
        case .dueDiligence: return .orange
        case .closed: return .green
        case .dead: return .red
        }
    }
}
