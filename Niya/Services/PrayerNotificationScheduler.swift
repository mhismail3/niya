import Foundation
import UserNotifications

enum PrayerNotificationScheduler {
    static let daysToSchedule = 12

    static func buildRequests(
        location: UserLocation,
        method: CalculationMethod,
        asrFactor: Int,
        now: Date = Date(),
        enabled: Bool = true
    ) -> [UNNotificationRequest] {
        guard enabled else { return [] }

        var requests: [UNNotificationRequest] = []
        var cal = Calendar.current
        cal.timeZone = location.timeZone
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = location.timeZone

        for dayOffset in 0..<daysToSchedule {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let times = PrayerTimeCalculator.calculate(
                date: date, location: location, method: method, asrFactor: asrFactor
            )
            for pt in times.times {
                guard pt.prayer.isActualPrayer, pt.time > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(pt.prayer.displayName) Prayer"
                content.body = "It's time for \(pt.prayer.displayName) - \(formatter.string(from: pt.time))"
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.categoryIdentifier = "prayerTime"

                let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: pt.time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let dayTag = cal.dateComponents([.year, .month, .day], from: pt.time)
                let id = "prayer_\(pt.prayer.rawValue)_\(dayTag.year!)_\(dayTag.month!)_\(dayTag.day!)"
                requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
        return requests
    }

    static func scheduleAll(location: UserLocation, method: CalculationMethod, asrFactor: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let requests = buildRequests(location: location, method: method, asrFactor: asrFactor)
        for request in requests {
            let requestID = request.identifier
            center.add(request) { error in
                if let error {
                    AppLogger.notification.error("Failed to schedule \(requestID): \(error.localizedDescription)")
                }
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func locationFromDefaults(userDefaults: UserDefaults = .standard) -> UserLocation? {
        guard let data = userDefaults.data(forKey: StorageKey.manualLocationData) else {
            return nil
        }
        return try? JSONDecoder().decode(UserLocation.self, from: data)
    }
}
