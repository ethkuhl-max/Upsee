import Foundation
import SwiftData
import SwiftUI

/// A per-entity adjustment within a scenario — override an app's MRR or a job's comp,
/// or exclude it entirely (e.g. "I quit this job").
struct ScenarioEntityOverride: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case app, job }

    var id: UUID
    var kind: Kind
    var targetName: String
    var included: Bool
    var monthlyValueOverride: Decimal?   // app MRR or job comp; nil = keep the entity's base value

    init(id: UUID = UUID(), kind: Kind, targetName: String, included: Bool = true, monthlyValueOverride: Decimal? = nil) {
        self.id = id
        self.kind = kind
        self.targetName = targetName
        self.included = included
        self.monthlyValueOverride = monthlyValueOverride
    }
}

/// A "what-if" projection layered over the user's current entities. Supports both
/// global overrides (income / expenses / months ahead) and per-entity overrides.
@Model
final class ScenarioEntity {
    var name: String
    var summary: String
    var monthlyIncomeOverride: Decimal?
    var monthlyExpensesOverride: Decimal?
    var startingBalanceOverride: Decimal?
    var monthsAhead: Int
    var startsAt: Date
    var createdAt: Date
    var updatedAt: Date

    /// JSON-encoded `[ScenarioEntityOverride]`.
    var entityOverridesData: Data?

    var entityOverrides: [ScenarioEntityOverride] {
        get {
            guard let entityOverridesData else { return [] }
            return (try? JSONDecoder().decode([ScenarioEntityOverride].self, from: entityOverridesData)) ?? []
        }
        set {
            entityOverridesData = newValue.isEmpty ? nil : (try? JSONEncoder().encode(newValue))
        }
    }

    init(
        name: String,
        summary: String = "",
        monthlyIncomeOverride: Decimal? = nil,
        monthlyExpensesOverride: Decimal? = nil,
        startingBalanceOverride: Decimal? = nil,
        monthsAhead: Int = 24,
        startsAt: Date = Date()
    ) {
        self.name = name
        self.summary = summary
        self.monthlyIncomeOverride = monthlyIncomeOverride
        self.monthlyExpensesOverride = monthlyExpensesOverride
        self.startingBalanceOverride = startingBalanceOverride
        self.monthsAhead = monthsAhead
        self.startsAt = startsAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.entityOverridesData = nil
    }

    /// True when nothing is overridden — the scenario is just "current state, projected forward."
    var isBaseline: Bool {
        monthlyIncomeOverride == nil
            && monthlyExpensesOverride == nil
            && startingBalanceOverride == nil
            && entityOverrides.isEmpty
    }
}
