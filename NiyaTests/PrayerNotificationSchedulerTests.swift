import Testing
import UserNotifications
@testable import Niya

@Suite("PrayerNotificationScheduler")
struct PrayerNotificationSchedulerTests {

    private let nyc = UserLocation(
        latitude: 40.7128,
        longitude: -74.0060,
        name: "New York, NY",
        timezoneIdentifier: "America/New_York"
    )

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.niya.mobile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func fixedDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func buildsRequestsForTwelveDays() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: now
        )
        #expect(requests.count == 60)
    }

    @Test func skipsPassedPrayers() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 14, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: now
        )
        #expect(requests.count < 60)
        #expect(requests.count > 50)
    }

    @Test func allTriggersAreCalendarBased() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: now
        )
        for request in requests {
            #expect(request.trigger is UNCalendarNotificationTrigger)
        }
    }

    @Test func noSunriseNotifications() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: now
        )
        for request in requests {
            #expect(!request.identifier.contains("sunrise"))
        }
    }

    @Test func identifiersAreUnique() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: now
        )
        let ids = Set(requests.map(\.identifier))
        #expect(ids.count == requests.count)
    }

    @Test func contentHasCorrectFields() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: now
        )
        let first = requests[0]
        #expect(first.content.title.hasSuffix("Prayer"))
        #expect(first.content.body.contains("It's time for"))
        #expect(first.content.sound == .default)
        #expect(first.content.interruptionLevel == .timeSensitive)
    }

    @Test func triggerDateComponentsMatchPrayerTime() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: now
        )

        let times = PrayerTimeCalculator.calculate(
            date: now, location: nyc, method: .isna, asrFactor: 1
        )
        let fajr = times.times.first { $0.prayer == .fajr }!

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let expectedHour = cal.component(.hour, from: fajr.time)
        let expectedMinute = cal.component(.minute, from: fajr.time)

        let fajrRequest = requests.first { $0.identifier.contains("fajr") }!
        let trigger = fajrRequest.trigger as! UNCalendarNotificationTrigger
        #expect(trigger.dateComponents.hour == expectedHour)
        #expect(trigger.dateComponents.minute == expectedMinute)
    }

    @Test("Friday Dhuhr notification says Jumuah")
    func fridayDhuhrNotification() {
        let tz = TimeZone(identifier: "America/New_York")!
        // 2026-03-27 is a Friday
        let friday = fixedDate(2026, 3, 27, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: friday
        )
        let dhuhr = requests.first { $0.identifier == "prayer_dhuhr_2026_3_27" }
        #expect(dhuhr?.content.title == "Jumuah Prayer")
        #expect(dhuhr?.content.body.contains("Jumuah") == true)
    }

    @Test("Non-Friday Dhuhr notification says Dhuhr")
    func saturdayDhuhrNotification() {
        let tz = TimeZone(identifier: "America/New_York")!
        // 2026-03-28 is a Saturday
        let saturday = fixedDate(2026, 3, 28, 0, 0, tz: tz)
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, now: saturday
        )
        // First dhuhr is Saturday's
        let dhuhr = requests.first { $0.identifier == "prayer_dhuhr_2026_3_28" }
        #expect(dhuhr?.content.title == "Dhuhr Prayer")
    }

    @Test func emptyWhenNotificationsDisabled() {
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, enabled: false
        )
        #expect(requests.isEmpty)
    }

    @Test func buildRequestsWorksOffMainThread() async {
        let location = nyc
        let tz = TimeZone(identifier: "America/New_York")!
        let now = fixedDate(2026, 3, 1, 0, 0, tz: tz)

        let count = await Task.detached {
            PrayerNotificationScheduler.buildRequests(
                location: location, method: .isna, asrFactor: 1, now: now
            ).count
        }.value

        #expect(count == 60)
    }

    @Test func locationFromDefaultsWorksOffMainThread() async {
        let defaults = makeDefaults()
        let encoded = try! JSONEncoder().encode(nyc)
        defaults.set(encoded, forKey: StorageKey.manualLocationData)

        let didComplete = await Task.detached {
            _ = PrayerNotificationScheduler.locationFromDefaults(userDefaults: defaults)
            return true
        }.value

        #expect(didComplete)
    }

    @Test func locationFromInjectedDefaultsDecodesStoredLocation() throws {
        let defaults = makeDefaults()
        defaults.set(try JSONEncoder().encode(nyc), forKey: StorageKey.manualLocationData)

        let decoded = PrayerNotificationScheduler.locationFromDefaults(userDefaults: defaults)

        #expect(decoded == nyc)
    }

    @Test func refreshConfigurationUsesStoredSettings() throws {
        let defaults = makeDefaults()
        defaults.set(true, forKey: StorageKey.prayerNotificationsEnabled)
        defaults.set(try JSONEncoder().encode(nyc), forKey: StorageKey.manualLocationData)
        defaults.set(CalculationMethod.makkah.rawValue, forKey: StorageKey.calculationMethod)
        defaults.set(2, forKey: StorageKey.asrJuristic)

        let configuration = PrayerRefreshBackgroundTask.configuration(userDefaults: defaults)

        #expect(configuration?.location == nyc)
        #expect(configuration?.method == .makkah)
        #expect(configuration?.asrFactor == 2)
    }

    @Test func refreshConfigurationNormalizesInvalidAsrFactor() throws {
        let defaults = makeDefaults()
        defaults.set(true, forKey: StorageKey.prayerNotificationsEnabled)
        defaults.set(try JSONEncoder().encode(nyc), forKey: StorageKey.manualLocationData)
        defaults.set(0, forKey: StorageKey.asrJuristic)

        let configuration = PrayerRefreshBackgroundTask.configuration(userDefaults: defaults)

        #expect(configuration?.asrFactor == 1)
    }

    @Test func refreshConfigurationRequiresEnabledNotificationsAndLocation() {
        let defaults = makeDefaults()

        #expect(PrayerRefreshBackgroundTask.configuration(userDefaults: defaults) == nil)

        defaults.set(true, forKey: StorageKey.prayerNotificationsEnabled)
        #expect(PrayerRefreshBackgroundTask.configuration(userDefaults: defaults) == nil)
    }

    @Test func refreshRequestBeginsAboutSixHoursAhead() {
        let now = Date(timeIntervalSinceReferenceDate: 123_456)

        let request = PrayerRefreshBackgroundTask.makeRequest(now: now)

        #expect(request.identifier == StorageKey.backgroundTaskIdentifier)
        #expect(request.earliestBeginDate == now.addingTimeInterval(6 * 3600))
    }
}
