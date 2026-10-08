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

    @ObservationIgnored nonisolated(unsafe) private var countdownTimer: Timer?
    @ObservationIgnored private var lastCalculationDate: Date?

    deinit {
        countdownTimer?.invalidate()
    }

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

        if let encoded = try? JSONEncoder().encode(location) {
            UserDefaults.standard.set(encoded, forKey: StorageKey.lastCalculatedLocation)
        }

        WidgetDataWriter.shared.write(today: result, tomorrow: tomorrowTimes, location: location, asrFactor: asrJuristic)
        WidgetDataWriter.shared.reloadTimelines()

        Task {
            if notificationsEnabled {
                await PrayerNotificationScheduler.scheduleAll(location: location, method: calculationMethod, asrFactor: asrJuristic)
            } else {
                await PrayerNotificationScheduler.cancelAll()
            }
        }
    }

    func checkDayChange(location: UserLocation?) {
        guard let loc = location else { return }
        if todayTimes == nil || Self.isDifferentLocalDay(lastCalculationDate ?? .distantPast, now: Date(), timeZone: loc.timeZone) {
            recalculate(location: loc)
        }
    }

    nonisolated static func isDifferentLocalDay(_ previous: Date, now: Date, timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return !calendar.isDate(previous, inSameDayAs: now)
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
