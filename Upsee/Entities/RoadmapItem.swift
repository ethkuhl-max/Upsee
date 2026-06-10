import Foundation
import SwiftData
import SwiftUI

@Model
final class RoadmapItem {
    var title: String
    var detail: String
    var statusRaw: String
    var priorityRaw: String
    var targetVersion: String?
    var estimatedHours: Double?
    var actualHours: Double?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    var app: AppEntity?

    var status: RoadmapStatus {
        get { RoadmapStatus(rawValue: statusRaw) ?? .idea }
        set {
            statusRaw = newValue.rawValue
            if newValue == .done && completedAt == nil {
                completedAt = Date()
            } else if newValue != .done {
                completedAt = nil
            }
        }
    }

    var priority: RoadmapPriority {
        get { RoadmapPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    init(
        title: String,
        detail: String = "",
        status: RoadmapStatus = .idea,
        priority: RoadmapPriority = .medium,
        targetVersion: String? = nil,
        estimatedHours: Double? = nil
    ) {
        self.title = title
        self.detail = detail
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.targetVersion = targetVersion
        self.estimatedHours = estimatedHours
        self.actualHours = nil
        self.sortOrder = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completedAt = status == .done ? Date() : nil
    }
}

enum RoadmapStatus: String, Codable, CaseIterable {
    case idea
    case planned
    case inProgress
    case done
    case scrapped

    var displayName: String {
        switch self {
        case .idea: return "Idea"
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .scrapped: return "Scrapped"
        }
    }

    var tint: Color {
        switch self {
        case .idea: return .gray
        case .planned: return .blue
        case .inProgress: return .orange
        case .done: return .green
        case .scrapped: return .secondary
        }
    }

    var sortRank: Int {
        switch self {
        case .inProgress: return 0
        case .planned: return 1
        case .idea: return 2
        case .done: return 3
        case .scrapped: return 4
        }
    }
}

enum RoadmapPriority: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var tint: Color {
        switch self {
        case .high: return .red
        case .medium: return .yellow
        case .low: return .secondary
        }
    }

    var symbol: String {
        switch self {
        case .high: return "arrow.up"
        case .medium: return "minus"
        case .low: return "arrow.down"
        }
    }
}
