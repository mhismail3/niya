import Foundation
import UIKit
import UserNotifications

enum AppUpdateReminderScheduler {
    static let identifier = "app_update_reminder_biweekly"
    static let reminderInterval: TimeInterval = 14 * 24 * 60 * 60
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/niya-make-your-intention/id6759700883")!

    static func isEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        guard userDefaults.object(forKey: StorageKey.appUpdateRemindersEnabled) != nil else {
            return true
        }
        return userDefaults.bool(forKey: StorageKey.appUpdateRemindersEnabled)
    }

    static func buildRequests(enabled: Bool = true) -> [UNNotificationRequest] {
        guard enabled else { return [] }

        let content = UNMutableNotificationContent()
        content.title = "Check for Niya Updates"
        content.body = "Open the App Store to make sure you have the latest version."
        content.sound = .default
        content.categoryIdentifier = "appUpdateReminder"
        content.userInfo = ["destination": "appStore"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderInterval, repeats: true)
        return [UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)]
    }

    static func scheduleIfNeeded(userDefaults: UserDefaults = .standard, force: Bool = false) async {
        guard isEnabled(userDefaults: userDefaults) else {
            cancel()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let pending = await center.pendingNotificationRequests()
        let alreadyScheduled = pending.contains { $0.identifier == identifier }
        guard force || !alreadyScheduled else { return }

        if alreadyScheduled {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
        for request in buildRequests() {
            do {
                try await center.add(request)
            } catch {
                AppLogger.notification.error("Failed to schedule \(request.identifier): \(error.localizedDescription)")
            }
        }
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

final class NotificationResponseHandler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationResponseHandler()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let completion = NotificationResponseCompletion(completionHandler)

        guard response.notification.request.identifier == AppUpdateReminderScheduler.identifier else {
            completion.finish()
            return
        }

        Task { @MainActor in
            UIApplication.shared.open(AppUpdateReminderScheduler.appStoreURL) { _ in
                completion.finish()
            }
        }
    }
}

private final class NotificationResponseCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private let handler: () -> Void
    private var hasCompleted = false

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }

        guard !hasCompleted else { return }
        hasCompleted = true
        handler()
    }
}
