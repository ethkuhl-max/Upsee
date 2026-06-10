import Foundation
import Observation
import SwiftData

/// Persistent in-memory state for the active stopwatch. Backed by UserDefaults so a
/// timer survives app quit / relaunch — losing yesterday's running timer would be
/// the kind of thing that makes Upsee not load-bearing.
@MainActor
@Observable
final class ActiveTimer {
    private static let key = "Upsee.ActiveTimer.v1"

    var startedAt: Date?
    var entityKind: String?
    var entityLabel: String?
    var note: String = ""

    init() {
        load()
    }

    var isRunning: Bool { startedAt != nil }

    var elapsedSeconds: Int {
        guard let started = startedAt else { return 0 }
        return Int(Date().timeIntervalSince(started))
    }

    var elapsedDisplay: String {
        let s = elapsedSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    func start(entityKind: String, entityLabel: String, note: String = "") {
        startedAt = Date()
        self.entityKind = entityKind
        self.entityLabel = entityLabel
        self.note = note
        persist()
    }

    @discardableResult
    func stop(modelContext: ModelContext) -> TimeEntry? {
        guard let started = startedAt,
              let kind = entityKind,
              let label = entityLabel else { return nil }
        let minutes = max(1, Int(Date().timeIntervalSince(started) / 60))
        let entry = TimeEntry(
            startedAt: started,
            minutes: minutes,
            note: note,
            entityKind: kind,
            entityLabel: label
        )
        modelContext.insert(entry)
        try? modelContext.save()
        clear()
        return entry
    }

    func cancel() {
        clear()
    }

    private func persist() {
        var dict: [String: Any] = ["note": note]
        if let started = startedAt { dict["startedAt"] = started.timeIntervalSinceReferenceDate }
        if let kind = entityKind { dict["entityKind"] = kind }
        if let label = entityLabel { dict["entityLabel"] = label }
        UserDefaults.standard.set(dict, forKey: Self.key)
    }

    private func load() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.key) else { return }
        if let stamp = dict["startedAt"] as? TimeInterval {
            startedAt = Date(timeIntervalSinceReferenceDate: stamp)
        }
        entityKind = dict["entityKind"] as? String
        entityLabel = dict["entityLabel"] as? String
        note = dict["note"] as? String ?? ""
    }

    private func clear() {
        startedAt = nil
        entityKind = nil
        entityLabel = nil
        note = ""
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
