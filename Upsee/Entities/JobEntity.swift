import Foundation
import SwiftData
import SwiftUI

@Model
final class JobEntity {
    var title: String
    var employer: String
    var statusRaw: String
    var startDate: Date?
    var endDate: Date?
    var monthlyCompensation: Decimal
    var hoursPerWeek: Int
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var status: JobStatus {
        get { JobStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        title: String,
        employer: String,
        status: JobStatus = .pending,
        monthlyCompensation: Decimal = 0,
        hoursPerWeek: Int = 40
    ) {
        self.title = title
        self.employer = employer
        self.statusRaw = status.rawValue
        self.startDate = nil
        self.endDate = nil
        self.monthlyCompensation = monthlyCompensation
        self.hoursPerWeek = hoursPerWeek
        self.note = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum JobStatus: String, Codable, CaseIterable {
    case pending
    case active
    case ended

    var displayName: String {
        switch self {
        case .pending: return "Pending Start"
        case .active: return "Active"
        case .ended: return "Ended"
        }
    }

    var tint: Color {
        switch self {
        case .pending: return .yellow
        case .active: return .green
        case .ended: return .gray
        }
    }
}
