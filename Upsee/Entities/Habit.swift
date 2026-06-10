import Foundation
import SwiftData

/// A recurring daily habit. Completions are stored as a set of day-keys (yyyy-MM-dd)
/// so streak math is a simple set membership check.
@Model
final class Habit {
    var name: String
    var systemImage: String
    var createdAt: Date
    var sortIndex: Int
    private var completionKeysData: Data?

    var completionDayKeys: Set<String> {
        get {
            guard let completionKeysData else { return [] }
            return (try? JSONDecoder().decode(Set<String>.self, from: completionKeysData)) ?? []
        }
        set {
            completionKeysData = newValue.isEmpty ? nil : (try? JSONEncoder().encode(newValue))
        }
    }

    init(name: String, systemImage: String = "checkmark.seal", sortIndex: Int = 0) {
        self.name = name
        self.systemImage = systemImage
        self.createdAt = Date()
        self.sortIndex = sortIndex
        self.completionKeysData = nil
    }

    func isComplete(on date: Date) -> Bool {
        completionDayKeys.contains(DayKey.string(from: date))
    }

    func toggle(on date: Date) {
        var keys = completionDayKeys
        let key = DayKey.string(from: date)
        if keys.contains(key) { keys.remove(key) } else { keys.insert(key) }
        completionDayKeys = keys
    }
}
