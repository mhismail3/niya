import Foundation
import UserNotifications

/// Single owner of pending prayer notifications. Runs are serialized: a new request
/// cancels the previous run and waits for it, so an on→off toggle or two quick
/// recalculations can never interleave old and new schedules.
actor PrayerNotificationOwner {
    static let shared = PrayerNotificationOwner()

    private var current: Task<Void, Never>?

    func schedule(location: UserLocation, method: CalculationMethod, asrFactor: Int) async {
        await enqueue { await Self.replace(location: location, method: method, asrFactor: asrFactor) }
    }

    func cancel() async {
        await enqueue { await Self.removeAllPrayerRequests() }
    }

    private func enqueue(_ operation: @escaping @Sendable () async -> Void) async {
        let previous = current
        previous?.cancel()
        let task = Task {
            await previous?.value
            await operation()
        }
        current = task
        // Forward the caller's cancellation (e.g. background-task expiration) to the work.
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func replace(location: UserLocation, method: CalculationMethod, asrFactor: Int) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
              UserDefaults.standard.bool(forKey: StorageKey.prayerNotificationsEnabled) else {
            await removeAllPrayerRequests()
            return
        }
        let requests = PrayerNotificationScheduler.buildRequests(location: location, method: method, asrFactor: asrFactor)
        // Adding a request with an existing identifier replaces it, so every day stays
        // covered throughout; only identifiers absent from the new schedule are removed.
        for request in requests {
            guard !Task.isCancelled else { return }
            do {
                try await center.add(request)
            } catch {
                AppLogger.notification.error("Failed to schedule \(request.identifier): \(error.localizedDescription)")
            }
        }
        guard !Task.isCancelled else { return }
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(
            withIdentifiers: PrayerNotificationScheduler.staleIdentifiers(pending: pending, desired: requests.map(\.identifier))
        )
    }

    private static func removeAllPrayerRequests() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: PrayerNotificationScheduler.prayerIdentifiers(from: pending))
    }
}
