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

    @Test func emptyWhenNotificationsDisabled() {
        let requests = PrayerNotificationScheduler.buildRequests(
            location: nyc, method: .isna, asrFactor: 1, enabled: false
        )
        #expect(requests.isEmpty)
    }
}
