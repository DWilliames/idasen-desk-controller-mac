//
//  NotificationManager.swift
//  Desk Controller
//
//  User-facing notifications for desk events (auto-stand reminders).
//

import Foundation
@preconcurrency import UserNotifications

@MainActor
final class NotificationManager {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let category = "DESK_REMINDER"
    private let standActionID = "DESK_REMINDER_STAND"
    private let sitActionID = "DESK_REMINDER_SIT"

    private var hasRegisteredCategory = false

    private init() {}

    /// Ask once for authorization. Safe to call repeatedly — the system de-dupes.
    ///
    /// `nonisolated` so the UNUserNotificationCenter completion handler — which
    /// runs on `com.apple.usernotifications.UNUserNotificationServiceConnection.call-out`
    /// — doesn't inherit @MainActor isolation from the class. Inheriting it caused
    /// the Swift runtime's `swift_task_checkIsolatedSwift` assertion to trap at
    /// app startup on macOS 26.
    nonisolated func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func registerCategoryIfNeeded() {
        guard !hasRegisteredCategory else { return }
        let standAction = UNNotificationAction(identifier: standActionID, title: "Stand", options: [.foreground])
        let sitAction = UNNotificationAction(identifier: sitActionID, title: "Sit", options: [.foreground])
        let cat = UNNotificationCategory(identifier: category,
                                         actions: [standAction, sitAction],
                                         intentIdentifiers: [],
                                         options: .customDismissAction)
        center.setNotificationCategories([cat])
        hasRegisteredCategory = true
    }

    /// Immediately post a reminder to stand up.
    func postStandReminder() {
        registerCategoryIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "Time to stand"
        content.body = "Your standing session is starting. Tap to raise the desk."
        content.categoryIdentifier = category
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    /// Immediately post a reminder to sit down.
    func postSitReminder() {
        registerCategoryIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "Time to sit"
        content.body = "Your standing session is over. Tap to lower the desk."
        content.categoryIdentifier = category
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    func notificationActionWasStand(_ actionIdentifier: String) -> Bool {
        actionIdentifier == standActionID
    }

    func notificationActionWasSit(_ actionIdentifier: String) -> Bool {
        actionIdentifier == sitActionID
    }
}
