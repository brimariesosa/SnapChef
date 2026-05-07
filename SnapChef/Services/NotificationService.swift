//
//  NotificationService.swift
//  SnapChef
//

import Foundation
import SwiftData
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    /// Days-before-expiry tiers we alert on, both as OS notifications and in
    /// the in-app bell list.
    static let alertDays: [Int] = [3, 2, 1, 0]

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

    // MARK: - OS notifications (scheduled to fire at the configured time)

    func scheduleExpirationAlert(for item: PantryItem) {
        cancelAlert(for: item)

        // Schedule a notification per batch (preferred) or fall back to the
        // legacy item-level expirationDate when no batches exist.
        if !item.batches.isEmpty {
            for batch in item.batches {
                guard let exp = batch.expirationDate else { continue }
                scheduleAlerts(
                    identifierBase: "exp-batch-\(batch.id.uuidString)",
                    itemId: item.id,
                    itemName: item.name,
                    expirationDate: exp
                )
            }
        } else if let exp = item.expirationDate {
            scheduleAlerts(
                identifierBase: "exp-item-\(item.id.uuidString)",
                itemId: item.id,
                itemName: item.name,
                expirationDate: exp
            )
        }
    }

    private func scheduleAlerts(
        identifierBase: String,
        itemId: UUID,
        itemName: String,
        expirationDate: Date
    ) {
        let cal = Calendar.current

        for days in Self.alertDays {
            // Fire each tier at 9:00 AM local time on the trigger day so users
            // see the alert during the day rather than at the moment the item
            // was added.
            guard let triggerDay = cal.date(byAdding: .day, value: -days, to: expirationDate),
                  let triggerDate = cal.date(
                    bySettingHour: 9, minute: 0, second: 0, of: triggerDay
                  ),
                  triggerDate > Date()
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = Self.titleFor(days: days)
            content.body = Self.bodyFor(itemName: itemName, days: days)
            content.sound = .default
            content.userInfo = [
                "itemId": itemId.uuidString,
                "daysUntilExpiry": days
            ]

            let comps = cal.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(identifierBase)-\(days)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule notification: \(error)")
                }
            }
        }
    }

    func cancelAlert(for item: PantryItem) {
        var ids: [String] = []
        for batch in item.batches {
            for days in Self.alertDays {
                ids.append("exp-batch-\(batch.id.uuidString)-\(days)")
            }
        }
        for days in Self.alertDays {
            ids.append("exp-item-\(item.id.uuidString)-\(days)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ids
        )
    }

    func rescheduleAll(items: [PantryItem]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for item in items {
            scheduleExpirationAlert(for: item)
        }
    }

    // MARK: - Copy

    static func titleFor(days: Int) -> String {
        switch days {
        case 0: return "Expires today"
        case 1: return "Expires tomorrow"
        default: return "Expires in \(days) days"
        }
    }

    static func bodyFor(itemName: String, days: Int) -> String {
        switch days {
        case 0: return "\(itemName) expires today — use it now."
        case 1: return "\(itemName) expires tomorrow."
        default: return "\(itemName) expires in \(days) days."
        }
    }
}

// MARK: - In-app notification sync
//
// Walks every pantry batch and creates an `AppNotification` for each tier
// (3 / 2 / 1 / 0 days) the batch is currently inside. Idempotent — re-running
// it never produces duplicates because ids are deterministic on (batchId, days).

enum InAppNotificationSync {

    /// Sync the in-app notification log against the current pantry state.
    /// - Inserts new entries when an item enters a 3/2/1/0-day window.
    /// - Removes entries whose underlying item has been deleted.
    /// Existing entries are left untouched so `isRead` is preserved.
    @MainActor
    static func sync(
        items: [PantryItem],
        existing: [AppNotification],
        context: ModelContext
    ) {
        let cal = Calendar.current
        let now = Date()
        let existingIds = Set(existing.map { $0.id })
        let validItemIds = Set(items.map { $0.id })

        for item in items {
            if !item.batches.isEmpty {
                for batch in item.batches {
                    guard let exp = batch.expirationDate else { continue }
                    insertIfDue(
                        idBase: "exp-batch-\(batch.id.uuidString)",
                        item: item,
                        expirationDate: exp,
                        now: now,
                        cal: cal,
                        existingIds: existingIds,
                        context: context
                    )
                }
            } else if let exp = item.expirationDate {
                insertIfDue(
                    idBase: "exp-item-\(item.id.uuidString)",
                    item: item,
                    expirationDate: exp,
                    now: now,
                    cal: cal,
                    existingIds: existingIds,
                    context: context
                )
            }
        }

        // Drop notifications whose pantry item no longer exists.
        for n in existing {
            if let id = n.itemId, !validItemIds.contains(id) {
                context.delete(n)
            }
        }
    }

    @MainActor
    private static func insertIfDue(
        idBase: String,
        item: PantryItem,
        expirationDate: Date,
        now: Date,
        cal: Calendar,
        existingIds: Set<String>,
        context: ModelContext
    ) {
        // Day-difference between today and expiry, ignoring time of day.
        let startOfNow = cal.startOfDay(for: now)
        let startOfExp = cal.startOfDay(for: expirationDate)
        guard let days = cal.dateComponents([.day], from: startOfNow, to: startOfExp).day else {
            return
        }

        for tier in NotificationService.alertDays where tier == days {
            let id = "\(idBase)-\(tier)"
            if existingIds.contains(id) { continue }

            let n = AppNotification(
                id: id,
                title: NotificationService.titleFor(days: tier),
                body: NotificationService.bodyFor(itemName: item.name, days: tier),
                itemId: item.id,
                itemName: item.name,
                daysUntilExpiry: tier,
                expirationDate: expirationDate,
                createdAt: now,
                isRead: false
            )
            context.insert(n)
        }
    }
}
