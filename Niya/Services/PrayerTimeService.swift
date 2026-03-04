import Foundation
import UserNotifications
import SwiftUI

@Observable
@MainActor
final class PrayerTimeService {
    var todayTimes: DailyPrayerTimes?
    var tomorrowTimes: DailyPrayerTimes?
    var countdown: TimeInterval = 0

    @ObservationIgnored
    @AppStorage(StorageKey.calculationMethod) private var storedMethod: String = CalculationMethod.isna.rawValue

    @ObservationIgnored
    @AppStorage(StorageKey.asrJuristic) private var asrJuristic: Int = 1

    @ObservationIgnored
    @AppStorage(StorageKey.prayerNotificationsEnabled) private var notificationsEnabled: Bool = false

    var calculationMethod: CalculationMethod {
        get { CalculationMethod(rawValue: storedMethod) ?? .isna }
        set { storedMethod = newValue.rawValue }
    }

    @ObservationIgnored private var countdownTimer: Timer?
    @ObservationIgnored private var lastCalculationDate: Date?

    var activeTimes: DailyPrayerTimes? {
        guard let today = todayTimes else { return nil }
        if today.nextPrayer(after: Date()) != nil { return today }
        return tomorrowTimes ?? today
    }

    func recalculate(location: UserLocation) {
        let now = Date()
        let result = PrayerTimeCalculator.calculate(
            date: now,
            location: location,
            method: calculationMethod,
            asrFactor: asrJuristic
        )
        todayTimes = result

        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else { return }
        tomorrowTimes = PrayerTimeCalculator.calculate(
            date: tomorrow,
            location: location,
            method: calculationMethod,
            asrFactor: asrJuristic
        )

        lastCalculationDate = now
        startCountdown()

        WidgetDataWriter.shared.write(today: result, tomorrow: tomorrowTimes, location: location, asrFactor: asrJuristic)
        WidgetDataWriter.shared.reloadTimelines()

        if notificationsEnabled {
            scheduleNotifications(times: result, timeZone: location.timeZone)
        }

        Task {
            await validateAgainstAPI(location: location, localTimes: result)
        }
    }

    func checkDayChange(location: UserLocation?) {
        guard let loc = location else { return }
        let cal = Calendar.current
        if let last = lastCalculationDate, !cal.isDateInToday(last) {
            recalculate(location: loc)
        }
    }

    func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                if let interval = self.todayTimes?.timeUntilNext(after: now)
                    ?? self.tomorrowTimes?.timeUntilNext(after: now) {
                    self.countdown = interval
                } else {
                    self.countdown = 0
                    self.countdownTimer?.invalidate()
                }
            }
        }
    }

    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Notifications

    func scheduleNotifications(times: DailyPrayerTimes, timeZone: TimeZone) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone

        for pt in times.times {
            guard pt.prayer.isActualPrayer, pt.time > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(pt.prayer.displayName) Prayer"
            content.body = "It's time for \(pt.prayer.displayName) - \(formatter.string(from: pt.time))"
            content.sound = .default
            content.categoryIdentifier = "prayerTime"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: pt.time.timeIntervalSince(now),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "prayer_\(pt.prayer.rawValue)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - API Validation

    private func validateAgainstAPI(location: UserLocation, localTimes: DailyPrayerTimes) async {
        guard let methodId = localTimes.method.aladhanMethodId else { return }
        let ts = Int(localTimes.date.timeIntervalSince1970)
        let urlString = "https://api.aladhan.com/v1/timings/\(ts)?latitude=\(location.latitude)&longitude=\(location.longitude)&method=\(methodId)"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await NetworkClient.shared.fetchRaw(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataObj = json?["data"] as? [String: Any],
                  let timings = dataObj["timings"] as? [String: String] else { return }

            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = location.timeZone

            let mapping: [(PrayerName, String)] = [
                (.fajr, "Fajr"), (.sunrise, "Sunrise"), (.dhuhr, "Dhuhr"),
                (.asr, "Asr"), (.maghrib, "Maghrib"), (.isha, "Isha")
            ]

            for (prayer, key) in mapping {
                guard let apiStr = timings[key],
                      let localPT = localTimes.times.first(where: { $0.prayer == prayer }) else { continue }

                let localStr = formatter.string(from: localPT.time)
                if let apiDate = formatter.date(from: String(apiStr.prefix(5))),
                   let localDate = formatter.date(from: localStr) {
                    let diff = abs(apiDate.timeIntervalSince(localDate)) / 60
                    if diff > 2 {
                        AppLogger.network.warning("Prayer time discrepancy for \(prayer.displayName): local=\(localStr) api=\(apiStr) diff=\(Int(diff))min")
                    }
                }
            }
        } catch {
            // Network/parsing errors are expected — validation is best-effort
        }
    }

    var formattedCountdown: String {
        guard countdown > 0 else { return "" }
        let hours = Int(countdown) / 3600
        let minutes = (Int(countdown) % 3600) / 60
        let seconds = Int(countdown) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
