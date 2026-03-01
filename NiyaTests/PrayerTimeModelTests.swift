import Foundation
import Testing
@testable import Niya

@Suite("PrayerTime Models")
struct PrayerTimeModelTests {

    @Test func prayerNameCount() {
        #expect(PrayerName.allCases.count == 6)
    }

    @Test func sunriseIsNotActualPrayer() {
        #expect(PrayerName.sunrise.isActualPrayer == false)
    }

    @Test func allOthersAreActualPrayers() {
        let actual = PrayerName.allCases.filter { $0.isActualPrayer }
        #expect(actual.count == 5)
        #expect(!actual.contains(.sunrise))
    }

    @Test func allHaveDisplayName() {
        for prayer in PrayerName.allCases {
            #expect(!prayer.displayName.isEmpty)
        }
    }

    @Test func allHaveIcon() {
        for prayer in PrayerName.allCases {
            #expect(!prayer.icon.isEmpty)
        }
    }

    @Test func nextPrayerReturnsFirstFuture() {
        let now = Date()
        let times = [
            PrayerTime(prayer: .fajr, time: now.addingTimeInterval(-3600)),
            PrayerTime(prayer: .sunrise, time: now.addingTimeInterval(-1800)),
            PrayerTime(prayer: .dhuhr, time: now.addingTimeInterval(1800)),
            PrayerTime(prayer: .asr, time: now.addingTimeInterval(7200)),
            PrayerTime(prayer: .maghrib, time: now.addingTimeInterval(14400)),
            PrayerTime(prayer: .isha, time: now.addingTimeInterval(18000)),
        ]
        let daily = DailyPrayerTimes(date: now, times: times, location: .mecca, method: .isna)
        let next = daily.nextPrayer(after: now)
        #expect(next?.prayer == .dhuhr)
    }

    @Test func nextPrayerReturnsNilWhenAllPassed() {
        let now = Date()
        let times = PrayerName.allCases.enumerated().map { i, prayer in
            PrayerTime(prayer: prayer, time: now.addingTimeInterval(-Double(6 - i) * 3600))
        }
        let daily = DailyPrayerTimes(date: now, times: times, location: .mecca, method: .isna)
        #expect(daily.nextPrayer(after: now) == nil)
    }

    @Test func timeUntilNextIsPositive() {
        let now = Date()
        let times = [
            PrayerTime(prayer: .fajr, time: now.addingTimeInterval(-3600)),
            PrayerTime(prayer: .dhuhr, time: now.addingTimeInterval(1800)),
        ]
        let daily = DailyPrayerTimes(date: now, times: times, location: .mecca, method: .isna)
        let interval = daily.timeUntilNext(after: now)
        #expect(interval != nil)
        #expect(interval! > 0)
    }

    @Test func timeUntilNextNilWhenAllPassed() {
        let now = Date()
        let times = [
            PrayerTime(prayer: .fajr, time: now.addingTimeInterval(-3600)),
        ]
        let daily = DailyPrayerTimes(date: now, times: times, location: .mecca, method: .isna)
        #expect(daily.timeUntilNext(after: now) == nil)
    }
}
