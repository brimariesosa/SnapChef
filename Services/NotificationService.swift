//
//  NotificationService.swift
//  SnapChef
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
            print("Notification permission: \(granted)")
        }
    }

    func scheduleExpirationAlert(for item: PantryItem) {
        guard let expDate = item.expirationDate else { return }

        let alertDate = Calendar.current.date(byAdding: .day, value: -2, to: expDate) ?? expDate
        guard alertDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Use it soon!"
        content.body = "Your \(item.name) expires in 2 days. Time to cook."
        content.sound = .default
        content.userInfo = ["itemId": item.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: alertDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "expiration-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func cancelAlert(for item: PantryItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["expiration-\(item.id.uuidString)"]
        )
    }

    func rescheduleAll(items: [PantryItem]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for item in items {
            scheduleExpirationAlert(for: item)
        }
    }
}
