import Foundation
import SwiftData
import SwiftUI

/// A record of an external data import — what came in, when, what changed.
/// Lets you reconstruct why an AppEntity's revenue moved without re-fetching.
@Model
final class ImportLogEntry {
    var importedAt: Date
    var sourceRaw: String
    var fileName: String
    var summary: String
    var changedEntityLabels: [String]
    var totalAmount: Decimal
    var unitsCount: Int

    var source: ImportSource {
        get { ImportSource(rawValue: sourceRaw) ?? .appStoreConnect }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        source: ImportSource,
        fileName: String,
        summary: String,
        changedEntityLabels: [String] = [],
        totalAmount: Decimal = 0,
        unitsCount: Int = 0
    ) {
        self.importedAt = Date()
        self.sourceRaw = source.rawValue
        self.fileName = fileName
        self.summary = summary
        self.changedEntityLabels = changedEntityLabels
        self.totalAmount = totalAmount
        self.unitsCount = unitsCount
    }
}

enum ImportSource: String, Codable, CaseIterable {
    case appStoreConnect
    case bankCSV
    case manualOverride

    var displayName: String {
        switch self {
        case .appStoreConnect: return "App Store Connect"
        case .bankCSV: return "Bank CSV"
        case .manualOverride: return "Manual Override"
        }
    }

    var systemImage: String {
        switch self {
        case .appStoreConnect: return "applelogo"
        case .bankCSV: return "building.columns"
        case .manualOverride: return "pencil"
        }
    }

    var tint: Color {
        switch self {
        case .appStoreConnect: return .blue
        case .bankCSV: return .green
        case .manualOverride: return .secondary
        }
    }
}
