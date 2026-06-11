import Foundation
import SwiftData

enum UpseeStore {
    static let schema = Schema([
        AppEntity.self,
        JobEntity.self,
        DealEntity.self,
        PersonalEntity.self,
        GoalEntity.self,
        ScenarioEntity.self,
        RoadmapItem.self,
        ReleaseEntry.self,
        AppGoal.self,
        BalanceSheetItem.self,
        DiligenceItem.self,
        BriefingEntity.self,
        TimeEntry.self,
        WellbeingEntry.self,
        Habit.self,
        NetWorthSnapshot.self,
        TaxPayment.self,
        RetirementAccount.self,
        DecisionEntity.self,
        Client.self,
        JournalEntry.self,
        WeeklyCommitment.self,
        AppCost.self,
        ImportLogEntry.self,
        Transaction.self,
        CategoryRule.self,
        Loan.self,
        Bill.self,
        Budget.self,
        InsurancePolicy.self,
        TargetAllocation.self,
        IPSDocument.self,
        EstateDocument.self,
    ])

    static let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create Upsee ModelContainer: \(error)")
        }
    }()
}
