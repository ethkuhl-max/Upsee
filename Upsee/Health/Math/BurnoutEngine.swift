import Foundation
import SwiftUI

/// A lightweight wellbeing sample (decoupled from SwiftData so the engine is testable).
struct WellbeingSample: Equatable {
    var energy: Int          // 1…5
    var stress: Int          // 1…5
    var sleepHours: Double
    var exerciseMinutes: Int
}

enum BurnoutBand: String {
    case low, moderate, elevated, high

    var label: String {
        switch self {
        case .low: return "Low risk"
        case .moderate: return "Moderate"
        case .elevated: return "Elevated"
        case .high: return "High risk"
        }
    }

    var tint: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .elevated: return .orange
        case .high: return .red
        }
    }

    init(score: Int) {
        switch score {
        case ..<25: self = .low
        case ..<50: self = .moderate
        case ..<70: self = .elevated
        default: self = .high
        }
    }
}

struct BurnoutAssessment: Equatable {
    let score: Int             // 0 (great) … 100 (high burnout risk)
    let drivers: [String]      // top contributing factors
    var band: BurnoutBand { BurnoutBand(score: score) }
}

/// Estimates burnout risk from recent wellbeing check-ins and weekly hours worked.
/// Missing wellbeing data falls back to neutral midpoints so the score still works
/// off hours alone.
enum BurnoutEngine {
    static func assess(entries: [WellbeingSample], weeklyWorkHours: Double) -> BurnoutAssessment {
        let avgSleep = average(entries.map(\.sleepHours), default: 7.5)
        let avgStress = average(entries.map { Double($0.stress) }, default: 3)
        let avgEnergy = average(entries.map { Double($0.energy) }, default: 3)
        let avgExercise = average(entries.map { Double($0.exerciseMinutes) }, default: 20)

        // Each component is a 0…1 risk contribution.
        let sleepRisk = clamp((7.5 - avgSleep) / 3.5)        // 7.5h → 0, 4h → 1
        let stressRisk = clamp((avgStress - 1) / 4)          // 1 → 0, 5 → 1
        let energyRisk = clamp((5 - avgEnergy) / 4)          // 5 → 0, 1 → 1
        let workRisk = clamp((weeklyWorkHours - 45) / 35)    // 45h → 0, 80h → 1
        let exerciseRisk = clamp((30 - avgExercise) / 30)    // 30m/day → 0, 0 → 1

        let weighted =
            stressRisk * 0.30 +
            sleepRisk * 0.25 +
            workRisk * 0.20 +
            energyRisk * 0.15 +
            exerciseRisk * 0.10

        let score = Int((weighted * 100).rounded())

        var drivers: [(String, Double)] = []
        if stressRisk > 0.45 { drivers.append(("High stress", stressRisk)) }
        if sleepRisk > 0.45 { drivers.append(("Short sleep (\(String(format: "%.1f", avgSleep))h avg)", sleepRisk)) }
        if workRisk > 0.45 { drivers.append(("Long hours (\(Int(weeklyWorkHours))h/wk)", workRisk)) }
        if energyRisk > 0.45 { drivers.append(("Low energy", energyRisk)) }
        if exerciseRisk > 0.6 { drivers.append(("Little exercise", exerciseRisk)) }
        let sortedDrivers = drivers.sorted { $0.1 > $1.1 }.map(\.0)

        return BurnoutAssessment(score: score, drivers: sortedDrivers)
    }

    private static func average(_ values: [Double], default fallback: Double) -> Double {
        guard !values.isEmpty else { return fallback }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
