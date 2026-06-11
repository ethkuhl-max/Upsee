import Foundation
import SwiftData
import SwiftUI

@Model
final class AppEntity {
    var name: String
    var summary: String
    var statusRaw: String
    var repoPath: String?
    var monthlyRevenue: Decimal
    var activeUsers: Int
    var lastShippedAt: Date?
    var marketingNote: String
    var techDebtNote: String
    var targetHoursPerWeek: Int = 0
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RoadmapItem.app)
    var roadmap: [RoadmapItem] = []

    @Relationship(deleteRule: .cascade, inverse: \ReleaseEntry.app)
    var releases: [ReleaseEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \AppGoal.app)
    var goals: [AppGoal] = []

    var status: AppStatus {
        get { AppStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        name: String,
        summary: String = "",
        status: AppStatus = .active,
        repoPath: String? = nil,
        monthlyRevenue: Decimal = 0,
        activeUsers: Int = 0
    ) {
        self.name = name
        self.summary = summary
        self.statusRaw = status.rawValue
        self.repoPath = repoPath
        self.monthlyRevenue = monthlyRevenue
        self.activeUsers = activeUsers
        self.lastShippedAt = nil
        self.marketingNote = ""
        self.techDebtNote = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var inFlightCount: Int {
        roadmap.filter { $0.status == .inProgress }.count
    }

    var plannedCount: Int {
        roadmap.filter { $0.status == .planned }.count
    }

    var ideaCount: Int {
        roadmap.filter { $0.status == .idea }.count
    }

    var latestRelease: ReleaseEntry? {
        releases.sorted { $0.releasedAt > $1.releasedAt }.first
    }

    var nextTargetVersion: String? {
        roadmap
            .filter { ($0.status == .inProgress || $0.status == .planned) && $0.targetVersion != nil }
            .compactMap { $0.targetVersion }
            .sorted()
            .first
    }

    var activeGoalCount: Int {
        goals.filter { $0.status == .active }.count
    }
}

enum AppStatus: String, Codable, CaseIterable {
    case active
    case maintenance
    case stalled
    case shipped
    case sunset

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .maintenance: return "Maintenance"
        case .stalled: return "Stalled"
        case .shipped: return "Shipped"
        case .sunset: return "Sunset"
        }
    }

    var tint: Color {
        switch self {
        case .active: return .green
        case .maintenance: return .blue
        case .stalled: return .orange
        case .shipped: return .purple
        case .sunset: return .gray
        }
    }
}
