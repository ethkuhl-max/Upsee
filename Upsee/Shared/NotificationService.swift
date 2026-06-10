import Foundation
import UserNotifications

/// Schedules local notifications for deal follow-ups and quarterly tax reminders.
enum NotificationService {
    private static let center = UNUserNotificationCenter.current()

    static func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Deal follow-ups

    private static func dealIdentifier(_ dealID: UUID) -> String { "deal-followup-\(dealID.uuidString)" }

    static func scheduleDealFollowUp(dealID: UUID, businessName: String, date: Date) {
        let id = dealIdentifier(dealID)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Follow up: \(businessName)"
        content.body = "You set a follow-up for this deal today."
        content.sound = .default

        center.add(request(id: id, content: content, onDay: date, hour: 9))
    }

    static func cancelDealFollowUp(dealID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [dealIdentifier(dealID)])
    }

    // MARK: - Quarterly tax

    static func scheduleTaxReminder(dueDate: Date, quarterlyAmount: Decimal) {
        let id = "tax-quarterly"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let remindDate = Calendar.current.date(byAdding: .day, value: -3, to: dueDate),
              remindDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Quarterly estimated taxes due soon"
        content.body = "Estimated payment of \(currency(quarterlyAmount)) is due \(Self.dateFormatter.string(from: dueDate))."
        content.sound = .default

        center.add(request(id: id, content: content, onDay: remindDate, hour: 9))
    }

    // MARK: - Helpers

    private static func request(id: String, content: UNMutableNotificationContent, onDay date: Date, hour: Int) -> UNNotificationRequest {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
}
