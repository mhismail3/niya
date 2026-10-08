import Foundation
import UserNotifications

enum PrayerNotificationScheduler {
    static let daysToSchedule = 12
    private static let identifierPrefix = "prayer_"

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
        let formatter = DateFormatter.prayerTime(timeZone: location.timeZone)

        for dayOffset in 0..<daysToSchedule {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let times = PrayerTimeCalculator.calculate(
                date: date, location: location, method: method, asrFactor: asrFactor
            )
            for pt in times.times {
                guard pt.prayer.isActualPrayer, pt.time > now else { continue }

                let content = UNMutableNotificationContent()
                let name = pt.prayer.displayName(on: date, calendar: cal)
                content.title = "\(name) Prayer"
                content.body = "It's time for \(name) - \(formatter.string(from: pt.time))"
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.categoryIdentifier = "prayerTime"

                // Include the location's time zone so the trigger fires at the prayer instant even
                // when the device is in a different time zone than a manually chosen location.
                let components = cal.dateComponents([.timeZone, .year, .month, .day, .hour, .minute], from: pt.time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let dayTag = cal.dateComponents([.year, .month, .day], from: pt.time)
                let id = "prayer_\(pt.prayer.rawValue)_\(dayTag.year!)_\(dayTag.month!)_\(dayTag.day!)"
                requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
        return requests
    }

    static func scheduleAll(location: UserLocation, method: CalculationMethod, asrFactor: Int) async {
        await PrayerNotificationOwner.shared.schedule(location: location, method: method, asrFactor: asrFactor)
    }

    static func cancelAll() async {
        await PrayerNotificationOwner.shared.cancel()
    }

    /// Pending prayer requests that the new schedule no longer contains (other apps' and
    /// non-prayer identifiers are never touched).
    static func staleIdentifiers(pending: [String], desired: [String]) -> [String] {
        let desiredSet = Set(desired)
        return prayerIdentifiers(from: pending).filter { !desiredSet.contains($0) }
    }

    static func prayerIdentifiers(from identifiers: [String]) -> [String] {
        identifiers.filter { $0.hasPrefix(identifierPrefix) }
    }

    static func locationFromDefaults(userDefaults: UserDefaults = .standard) -> UserLocation? {
        if let data = userDefaults.data(forKey: StorageKey.manualLocationData),
           let loc = try? JSONDecoder().decode(UserLocation.self, from: data) {
            return loc
        }
        if let data = userDefaults.data(forKey: StorageKey.lastCalculatedLocation),
           let loc = try? JSONDecoder().decode(UserLocation.self, from: data) {
            return loc
        }
        return nil
    }
}
