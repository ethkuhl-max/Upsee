import Foundation
import SwiftData

/// A portable JSON snapshot of the user's core Upsee data — portfolio, deals + analyses,
/// planning, balance sheet, advisor clients, and wellbeing/habits. Operator-tooling
/// entities (roadmap, releases, briefings, time entries) are intentionally excluded.
struct UpseeBackup: Codable {
    var version: Int = 2
    var exportedAt: Date
    var apps: [AppDTO]
    var jobs: [JobDTO]
    var personal: [PersonalDTO]
    var goals: [GoalDTO]
    var scenarios: [ScenarioDTO]
    var deals: [DealDTO]
    var diligence: [DiligenceDTO]
    var balanceSheet: [BalanceSheetDTO]
    // Added in v2 — optional so v1 backups still decode.
    var clients: [ClientDTO]?
    var wellbeing: [WellbeingDTO]?
    var habits: [HabitDTO]?
    // Added in v3.
    var retirementAccounts: [RetirementDTO]?
    var netWorthSnapshots: [SnapshotDTO]?
    var taxPayments: [TaxPaymentDTO]?
    var decisions: [DecisionDTO]?

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
    struct ClientDTO: Codable {
        var name: String; var email: String; var householdNote: String; var statusRaw: String
        var aum: Decimal; var feePercent: Double; var riskScore: Int
        var monthlyIncome: Decimal; var monthlyExpenses: Decimal
        var reviewCadenceMonths: Int; var lastReviewDate: Date?; var notes: String
        var createdAt: Date; var updatedAt: Date
        var lineItems: [ClientLineItem]; var meetings: [ClientMeeting]
        var riskAnswers: [Int]; var goals: [ClientGoal]
    }
    struct WellbeingDTO: Codable {
        var date: Date; var energy: Int; var stress: Int; var sleepHours: Double
        var exerciseMinutes: Int; var note: String
    }
    struct HabitDTO: Codable {
        var name: String; var systemImage: String; var sortIndex: Int; var createdAt: Date
        var completionDayKeys: [String]
    }
    struct RetirementDTO: Codable {
        var name: String; var kindRaw: String; var currentBalance: Decimal
        var contributionsYTD: Decimal; var employerMatchYTD: Decimal; var note: String
        var createdAt: Date; var updatedAt: Date
    }
    struct SnapshotDTO: Codable {
        var date: Date; var totalAssets: Decimal; var totalLiabilities: Decimal
        var cashAmount: Decimal; var investmentsAmount: Decimal; var retirementAmount: Decimal
        var realEstateAmount: Decimal; var vehicleAmount: Decimal; var otherAssetAmount: Decimal
        var creditCardAmount: Decimal; var studentLoanAmount: Decimal; var autoLoanAmount: Decimal
        var mortgageAmount: Decimal; var otherLiabilityAmount: Decimal; var note: String; var createdAt: Date
    }
    struct TaxPaymentDTO: Codable {
        var paidAt: Date; var amount: Decimal; var quarterNumber: Int; var taxYear: Int
        var kindRaw: String; var note: String; var createdAt: Date
    }
    struct DecisionDTO: Codable {
        var createdAt: Date; var kindRaw: String; var targetLabel: String
        var recommendation: String; var userChoice: String; var rationale: String
        var outcome: String; var outcomeUpdatedAt: Date?
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
            },
            clients: fetch(context, Client.self).map {
                .init(name: $0.name, email: $0.email, householdNote: $0.householdNote, statusRaw: $0.statusRaw,
                      aum: $0.aum, feePercent: $0.feePercent, riskScore: $0.riskScore,
                      monthlyIncome: $0.monthlyIncome, monthlyExpenses: $0.monthlyExpenses,
                      reviewCadenceMonths: $0.reviewCadenceMonths, lastReviewDate: $0.lastReviewDate, notes: $0.notes,
                      createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                      lineItems: $0.lineItems, meetings: $0.meetings, riskAnswers: $0.riskAnswers, goals: $0.goals)
            },
            wellbeing: fetch(context, WellbeingEntry.self).map {
                .init(date: $0.date, energy: $0.energy, stress: $0.stress, sleepHours: $0.sleepHours,
                      exerciseMinutes: $0.exerciseMinutes, note: $0.note)
            },
            habits: fetch(context, Habit.self).map {
                .init(name: $0.name, systemImage: $0.systemImage, sortIndex: $0.sortIndex,
                      createdAt: $0.createdAt, completionDayKeys: Array($0.completionDayKeys))
            },
            retirementAccounts: fetch(context, RetirementAccount.self).map {
                .init(name: $0.name, kindRaw: $0.kindRaw, currentBalance: $0.currentBalance,
                      contributionsYTD: $0.contributionsYTD, employerMatchYTD: $0.employerMatchYTD,
                      note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            netWorthSnapshots: fetch(context, NetWorthSnapshot.self).map {
                .init(date: $0.date, totalAssets: $0.totalAssets, totalLiabilities: $0.totalLiabilities,
                      cashAmount: $0.cashAmount, investmentsAmount: $0.investmentsAmount, retirementAmount: $0.retirementAmount,
                      realEstateAmount: $0.realEstateAmount, vehicleAmount: $0.vehicleAmount, otherAssetAmount: $0.otherAssetAmount,
                      creditCardAmount: $0.creditCardAmount, studentLoanAmount: $0.studentLoanAmount, autoLoanAmount: $0.autoLoanAmount,
                      mortgageAmount: $0.mortgageAmount, otherLiabilityAmount: $0.otherLiabilityAmount, note: $0.note, createdAt: $0.createdAt)
            },
            taxPayments: fetch(context, TaxPayment.self).map {
                .init(paidAt: $0.paidAt, amount: $0.amount, quarterNumber: $0.quarterNumber, taxYear: $0.taxYear,
                      kindRaw: $0.kindRaw, note: $0.note, createdAt: $0.createdAt)
            },
            decisions: fetch(context, DecisionEntity.self).map {
                .init(createdAt: $0.createdAt, kindRaw: $0.kindRaw, targetLabel: $0.targetLabel,
                      recommendation: $0.recommendation, userChoice: $0.userChoice, rationale: $0.rationale,
                      outcome: $0.outcome, outcomeUpdatedAt: $0.outcomeUpdatedAt)
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
        deleteAll(context, Client.self)
        deleteAll(context, WellbeingEntry.self)
        deleteAll(context, Habit.self)
        deleteAll(context, RetirementAccount.self)
        deleteAll(context, NetWorthSnapshot.self)
        deleteAll(context, TaxPayment.self)
        deleteAll(context, DecisionEntity.self)

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
        for dto in backup.clients ?? [] {
            let e = Client(name: dto.name, email: dto.email,
                           status: ClientStatus(rawValue: dto.statusRaw) ?? .prospect,
                           aum: dto.aum, feePercent: dto.feePercent, reviewCadenceMonths: dto.reviewCadenceMonths)
            e.householdNote = dto.householdNote; e.riskScore = dto.riskScore
            e.monthlyIncome = dto.monthlyIncome; e.monthlyExpenses = dto.monthlyExpenses
            e.lastReviewDate = dto.lastReviewDate; e.notes = dto.notes
            e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt
            e.lineItems = dto.lineItems; e.meetings = dto.meetings; e.riskAnswers = dto.riskAnswers; e.goals = dto.goals
            context.insert(e)
        }
        for dto in backup.wellbeing ?? [] {
            let e = WellbeingEntry(date: dto.date, energy: dto.energy, stress: dto.stress,
                                   sleepHours: dto.sleepHours, exerciseMinutes: dto.exerciseMinutes, note: dto.note)
            context.insert(e)
        }
        for dto in backup.habits ?? [] {
            let e = Habit(name: dto.name, systemImage: dto.systemImage, sortIndex: dto.sortIndex)
            e.createdAt = dto.createdAt
            e.completionDayKeys = Set(dto.completionDayKeys)
            context.insert(e)
        }
        for dto in backup.retirementAccounts ?? [] {
            let e = RetirementAccount(name: dto.name,
                                      kind: RetirementAccountKind(rawValue: dto.kindRaw) ?? .traditionalIRA,
                                      currentBalance: dto.currentBalance, contributionsYTD: dto.contributionsYTD,
                                      employerMatchYTD: dto.employerMatchYTD)
            e.note = dto.note; e.createdAt = dto.createdAt; e.updatedAt = dto.updatedAt
            context.insert(e)
        }
        for dto in backup.netWorthSnapshots ?? [] {
            let e = NetWorthSnapshot(date: dto.date, totalAssets: dto.totalAssets, totalLiabilities: dto.totalLiabilities,
                                     cashAmount: dto.cashAmount, investmentsAmount: dto.investmentsAmount, retirementAmount: dto.retirementAmount,
                                     realEstateAmount: dto.realEstateAmount, vehicleAmount: dto.vehicleAmount, otherAssetAmount: dto.otherAssetAmount,
                                     creditCardAmount: dto.creditCardAmount, studentLoanAmount: dto.studentLoanAmount, autoLoanAmount: dto.autoLoanAmount,
                                     mortgageAmount: dto.mortgageAmount, otherLiabilityAmount: dto.otherLiabilityAmount, note: dto.note)
            e.createdAt = dto.createdAt
            context.insert(e)
        }
        for dto in backup.taxPayments ?? [] {
            let e = TaxPayment(paidAt: dto.paidAt, amount: dto.amount, quarterNumber: dto.quarterNumber,
                               taxYear: dto.taxYear, kind: TaxPaymentKind(rawValue: dto.kindRaw) ?? .federal, note: dto.note)
            e.createdAt = dto.createdAt
            context.insert(e)
        }
        for dto in backup.decisions ?? [] {
            let e = DecisionEntity(kind: DecisionKind(rawValue: dto.kindRaw) ?? .app, targetLabel: dto.targetLabel,
                                   recommendation: dto.recommendation, userChoice: dto.userChoice, rationale: dto.rationale)
            e.createdAt = dto.createdAt; e.outcome = dto.outcome; e.outcomeUpdatedAt = dto.outcomeUpdatedAt
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
