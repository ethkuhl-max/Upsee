import Foundation
import SwiftData

/// A portable JSON snapshot of the user's core Upsee data. Operator-tooling entities
/// (roadmap, releases, briefings, time entries) are intentionally excluded — this covers
/// the portfolio, deals + analyses, planning, and the balance sheet.
struct UpseeBackup: Codable {
    var version: Int = 1
    var exportedAt: Date
    var apps: [AppDTO]
    var jobs: [JobDTO]
    var personal: [PersonalDTO]
    var goals: [GoalDTO]
    var scenarios: [ScenarioDTO]
    var deals: [DealDTO]
    var diligence: [DiligenceDTO]
    var balanceSheet: [BalanceSheetDTO]

    struct AppDTO: Codable {
        var name: String; var summary: String; var statusRaw: String; var repoPath: String?
        var monthlyRevenue: Decimal; var activeUsers: Int; var lastShippedAt: Date?
        var marketingNote: String; var techDebtNote: String; var createdAt: Date; var updatedAt: Date
    }
    struct JobDTO: Codable {
        var title: String; var employer: String; var statusRaw: String
        var startDate: Date?; var endDate: Date?; var monthlyCompensation: Decimal
        var hoursPerWeek: Int; var note: String; var createdAt: Date; var updatedAt: Date
    }
    struct PersonalDTO: Codable {
        var monthlyIncome: Decimal; var monthlyExpenses: Decimal; var currentSavings: Decimal
        var taxBracketEstimate: Double; var note: String; var updatedAt: Date
        var filingStatusRaw: String; var stateTaxRate: Double; var selfEmploymentPortion: Double
    }
    struct GoalDTO: Codable {
        var name: String; var summary: String; var targetAmount: Decimal; var currentAmount: Decimal
        var targetDate: Date?; var statusRaw: String; var createdAt: Date; var updatedAt: Date
    }
    struct ScenarioDTO: Codable {
        var name: String; var summary: String; var monthlyIncomeOverride: Decimal?
        var monthlyExpensesOverride: Decimal?; var startingBalanceOverride: Decimal?
        var monthsAhead: Int; var startsAt: Date; var createdAt: Date; var updatedAt: Date
        var entityOverridesData: Data?
    }
    struct DealDTO: Codable {
        var dealID: UUID; var businessName: String; var industryRaw: String; var location: String?
        var askingPrice: Decimal; var reportedSDE: Decimal; var lastVerdictLabel: String
        var lastVerdictHeadline: String; var statusRaw: String; var sourcePDFPath: String?
        var note: String; var followUpDate: Date?; var lastAnalyzedAt: Date?
        var createdAt: Date; var updatedAt: Date; var analysisData: Data?
    }
    struct DiligenceDTO: Codable {
        var dealID: UUID; var text: String; var isDone: Bool; var sortIndex: Int; var createdAt: Date
    }
    struct BalanceSheetDTO: Codable {
        var name: String; var amount: Decimal; var isAsset: Bool; var categoryRaw: String
        var apr: Double; var minimumPayment: Decimal; var createdAt: Date; var updatedAt: Date
    }
}

enum BackupService {
    @MainActor
    static func export(_ context: ModelContext) -> Data? {
        let backup = UpseeBackup(
            exportedAt: Date(),
            apps: fetch(context, AppEntity.self).map {
                .init(name: $0.name, summary: $0.summary, statusRaw: $0.statusRaw, repoPath: $0.repoPath,
                      monthlyRevenue: $0.monthlyRevenue, activeUsers: $0.activeUsers, lastShippedAt: $0.lastShippedAt,
                      marketingNote: $0.marketingNote, techDebtNote: $0.techDebtNote, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            jobs: fetch(context, JobEntity.self).map {
                .init(title: $0.title, employer: $0.employer, statusRaw: $0.statusRaw, startDate: $0.startDate,
                      endDate: $0.endDate, monthlyCompensation: $0.monthlyCompensation, hoursPerWeek: $0.hoursPerWeek,
                      note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            personal: fetch(context, PersonalEntity.self).map {
                .init(monthlyIncome: $0.monthlyIncome, monthlyExpenses: $0.monthlyExpenses, currentSavings: $0.currentSavings,
                      taxBracketEstimate: $0.taxBracketEstimate, note: $0.note, updatedAt: $0.updatedAt,
                      filingStatusRaw: $0.filingStatusRaw, stateTaxRate: $0.stateTaxRate, selfEmploymentPortion: $0.selfEmploymentPortion)
            },
            goals: fetch(context, GoalEntity.self).map {
                .init(name: $0.name, summary: $0.summary, targetAmount: $0.targetAmount, currentAmount: $0.currentAmount,
                      targetDate: $0.targetDate, statusRaw: $0.statusRaw, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            scenarios: fetch(context, ScenarioEntity.self).map {
                .init(name: $0.name, summary: $0.summary, monthlyIncomeOverride: $0.monthlyIncomeOverride,
                      monthlyExpensesOverride: $0.monthlyExpensesOverride, startingBalanceOverride: $0.startingBalanceOverride,
                      monthsAhead: $0.monthsAhead, startsAt: $0.startsAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                      entityOverridesData: $0.entityOverridesData)
            },
            deals: fetch(context, DealEntity.self).map {
                .init(dealID: $0.dealID, businessName: $0.businessName, industryRaw: $0.industryRaw, location: $0.location,
                      askingPrice: $0.askingPrice, reportedSDE: $0.reportedSDE, lastVerdictLabel: $0.lastVerdictLabel,
                      lastVerdictHeadline: $0.lastVerdictHeadline, statusRaw: $0.statusRaw, sourcePDFPath: $0.sourcePDFPath,
                      note: $0.note, followUpDate: $0.followUpDate, lastAnalyzedAt: $0.lastAnalyzedAt,
                      createdAt: $0.createdAt, updatedAt: $0.updatedAt, analysisData: $0.analysisData)
            },
            diligence: fetch(context, DiligenceItem.self).map {
                .init(dealID: $0.dealID, text: $0.text, isDone: $0.isDone, sortIndex: $0.sortIndex, createdAt: $0.createdAt)
            },
            balanceSheet: fetch(context, BalanceSheetItem.self).map {
                .init(name: $0.name, amount: $0.amount, isAsset: $0.isAsset, categoryRaw: $0.categoryRaw,
                      apr: $0.apr, minimumPayment: $0.minimumPayment, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    /// Replaces all covered entities with the backup's contents. Returns true on success.
    @MainActor
    @discardableResult
    static func restore(_ data: Data, into context: ModelContext) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(UpseeBackup.self, from: data) else { return false }

        deleteAll(context, AppEntity.self)
        deleteAll(context, JobEntity.self)
        deleteAll(context, PersonalEntity.self)
        deleteAll(context, GoalEntity.self)
        deleteAll(context, ScenarioEntity.self)
        deleteAll(context, DealEntity.self)
        deleteAll(context, DiligenceItem.self)
        deleteAll(context, BalanceSheetItem.self)

        for dto in backup.apps {
            let e = AppEntity(name: dto.name, summary: dto.summary, repoPath: dto.repoPath,
                              monthlyRevenue: dto.monthlyRevenue, activeUsers: dto.activeUsers)
            e.statusRaw = dto.statusRaw; e.lastShippedAt = dto.lastShippedAt; e.marketingNote = dto.marketingNote
            e.techDebtNote = dto.techDebtNote; e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt
            context.insert(e)
        }
        for dto in backup.jobs {
            let e = JobEntity(title: dto.title, employer: dto.employer, monthlyCompensation: dto.monthlyCompensation, hoursPerWeek: dto.hoursPerWeek)
            e.statusRaw = dto.statusRaw; e.startDate = dto.startDate; e.endDate = dto.endDate
            e.note = dto.note; e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt
            context.insert(e)
        }
        for dto in backup.personal {
            let e = PersonalEntity(monthlyIncome: dto.monthlyIncome, monthlyExpenses: dto.monthlyExpenses,
                                   currentSavings: dto.currentSavings, taxBracketEstimate: dto.taxBracketEstimate)
            e.note = dto.note; e.updatedAt = dto.updatedAt; e.filingStatusRaw = dto.filingStatusRaw
            e.stateTaxRate = dto.stateTaxRate; e.selfEmploymentPortion = dto.selfEmploymentPortion
            context.insert(e)
        }
        for dto in backup.goals {
            let e = GoalEntity(name: dto.name, summary: dto.summary, targetAmount: dto.targetAmount,
                               currentAmount: dto.currentAmount, targetDate: dto.targetDate)
            e.statusRaw = dto.statusRaw; e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt
            context.insert(e)
        }
        for dto in backup.scenarios {
            let e = ScenarioEntity(name: dto.name, summary: dto.summary, monthlyIncomeOverride: dto.monthlyIncomeOverride,
                                   monthlyExpensesOverride: dto.monthlyExpensesOverride, startingBalanceOverride: dto.startingBalanceOverride,
                                   monthsAhead: dto.monthsAhead, startsAt: dto.startsAt)
            e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt; e.entityOverridesData = dto.entityOverridesData
            context.insert(e)
        }
        for dto in backup.deals {
            let e = DealEntity(businessName: dto.businessName)
            e.dealID = dto.dealID; e.industryRaw = dto.industryRaw; e.location = dto.location
            e.askingPrice = dto.askingPrice; e.reportedSDE = dto.reportedSDE; e.lastVerdictLabel = dto.lastVerdictLabel
            e.lastVerdictHeadline = dto.lastVerdictHeadline; e.statusRaw = dto.statusRaw; e.sourcePDFPath = dto.sourcePDFPath
            e.note = dto.note; e.followUpDate = dto.followUpDate; e.lastAnalyzedAt = dto.lastAnalyzedAt
            e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt; e.analysisData = dto.analysisData
            context.insert(e)
        }
        for dto in backup.diligence {
            let e = DiligenceItem(dealID: dto.dealID, text: dto.text, isDone: dto.isDone, sortIndex: dto.sortIndex)
            e.createdAt = dto.createdAt
            context.insert(e)
        }
        for dto in backup.balanceSheet {
            let e = BalanceSheetItem(name: dto.name, amount: dto.amount,
                                     category: BalanceSheetCategory(rawValue: dto.categoryRaw) ?? .otherAsset,
                                     apr: dto.apr, minimumPayment: dto.minimumPayment)
            e.isAsset = dto.isAsset; e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt
            context.insert(e)
        }

        try? context.save()
        return true
    }

    // MARK: - Helpers

    private static func fetch<T: PersistentModel>(_ context: ModelContext, _ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private static func deleteAll<T: PersistentModel>(_ context: ModelContext, _ type: T.Type) {
        for item in fetch(context, type) { context.delete(item) }
    }
}
