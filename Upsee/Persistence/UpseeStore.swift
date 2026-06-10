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
    ])

    static let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create Upsee ModelContainer: \(error)")
        }
    }()
}
