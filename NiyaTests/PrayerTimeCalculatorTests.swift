import Foundation
import Testing
@testable import Niya

@Suite("PrayerTimeCalculator")
struct PrayerTimeCalculatorTests {

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.timeZone = tz
        return cal.date(from: comps)!
    }

    private func hourMinute(from date: Date, tz: TimeZone) -> (Int, Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.hour, .minute], from: date)
        return (comps.hour!, comps.minute!)
    }

    private func minutesDiff(_ date: Date, targetHour: Int, targetMinute: Int, tz: TimeZone) -> Int {
        let (h, m) = hourMinute(from: date, tz: tz)
        return abs((h * 60 + m) - (targetHour * 60 + targetMinute))
    }

    // MARK: - Mecca, 2024-03-15, ISNA (verified against Aladhan API)

    @Test func meccaISNA() {
        let tz = TimeZone(identifier: "Asia/Riyadh")!
        let date = makeDate(year: 2024, month: 3, day: 15, tz: tz)
        let loc = UserLocation(latitude: 21.4225, longitude: 39.8262, name: "Mecca", timezoneIdentifier: "Asia/Riyadh")
        let result = PrayerTimeCalculator.calculate(date: date, location: loc, method: .isna)

        let tolerance = 3
        for pt in result.times {
            let (h, m) = hourMinute(from: pt.time, tz: tz)
            switch pt.prayer {
            case .fajr:    #expect(minutesDiff(pt.time, targetHour: 5, targetMinute: 28, tz: tz) <= tolerance, "Fajr: \(h):\(m)")
            case .sunrise: #expect(minutesDiff(pt.time, targetHour: 6, targetMinute: 29, tz: tz) <= tolerance, "Sunrise: \(h):\(m)")
            case .dhuhr:   #expect(minutesDiff(pt.time, targetHour: 12, targetMinute: 29, tz: tz) <= tolerance, "Dhuhr: \(h):\(m)")
            case .asr:     #expect(minutesDiff(pt.time, targetHour: 15, targetMinute: 53, tz: tz) <= tolerance, "Asr: \(h):\(m)")
            case .maghrib: #expect(minutesDiff(pt.time, targetHour: 18, targetMinute: 30, tz: tz) <= tolerance, "Maghrib: \(h):\(m)")
            case .isha:    #expect(minutesDiff(pt.time, targetHour: 19, targetMinute: 31, tz: tz) <= tolerance, "Isha: \(h):\(m)")
            }
        }
    }

    // MARK: - DST change day

    /// 2024-03-10 is the US spring-forward day. Times must not depend on whether the
    /// input instant is before (EST) or after (EDT) the 02:00 switch.
    @Test func dstChangeDayIsIndependentOfInputInstant() {
        let tz = TimeZone(identifier: "America/New_York")!
        let loc = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")
        let midnight = PrayerTimeCalculator.calculate(date: makeDate(year: 2024, month: 3, day: 10, hour: 0, tz: tz), location: loc, method: .isna)
        let noon = PrayerTimeCalculator.calculate(date: makeDate(year: 2024, month: 3, day: 10, hour: 12, tz: tz), location: loc, method: .isna)
        #expect(midnight.times.map(\.time) == noon.times.map(\.time))
        let maghrib = noon.times.first { $0.prayer == .maghrib }!.time
        #expect(minutesDiff(maghrib, targetHour: 19, targetMinute: 0, tz: tz) <= 5, "Maghrib on DST day: \(hourMinute(from: maghrib, tz: tz))")
    }

    // MARK: - New York, 2024-03-15, ISNA (verified against Aladhan API)

    @Test func newYorkISNA() {
        let tz = TimeZone(identifier: "America/New_York")!
        let date = makeDate(year: 2024, month: 3, day: 15, tz: tz)
        let loc = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")
        let result = PrayerTimeCalculator.calculate(date: date, location: loc, method: .isna)

        let tolerance = 3
        for pt in result.times {
            let (h, m) = hourMinute(from: pt.time, tz: tz)
            switch pt.prayer {
            case .fajr:    #expect(minutesDiff(pt.time, targetHour: 5, targetMinute: 52, tz: tz) <= tolerance, "Fajr: \(h):\(m)")
            case .sunrise: #expect(minutesDiff(pt.time, targetHour: 7, targetMinute: 7, tz: tz) <= tolerance, "Sunrise: \(h):\(m)")
            case .dhuhr:   #expect(minutesDiff(pt.time, targetHour: 13, targetMinute: 5, tz: tz) <= tolerance, "Dhuhr: \(h):\(m)")
            case .asr:     #expect(minutesDiff(pt.time, targetHour: 16, targetMinute: 26, tz: tz) <= tolerance, "Asr: \(h):\(m)")
            case .maghrib: #expect(minutesDiff(pt.time, targetHour: 19, targetMinute: 3, tz: tz) <= tolerance, "Maghrib: \(h):\(m)")
            case .isha:    #expect(minutesDiff(pt.time, targetHour: 20, targetMinute: 19, tz: tz) <= tolerance, "Isha: \(h):\(m)")
            }
        }
    }

    // MARK: - London summer solstice, MWL (verified against Aladhan API)

    @Test func londonSummerSolsticeMWL() {
        let tz = TimeZone(identifier: "Europe/London")!
        let date = makeDate(year: 2024, month: 6, day: 21, tz: tz)
        let loc = UserLocation(latitude: 51.5074, longitude: -0.1278, name: "London", timezoneIdentifier: "Europe/London")
        let result = PrayerTimeCalculator.calculate(date: date, location: loc, method: .mwl)

        let tolerance = 5
        for pt in result.times {
            let (h, m) = hourMinute(from: pt.time, tz: tz)
            switch pt.prayer {
            case .sunrise: #expect(minutesDiff(pt.time, targetHour: 4, targetMinute: 43, tz: tz) <= tolerance, "Sunrise: \(h):\(m)")
            case .dhuhr:   #expect(minutesDiff(pt.time, targetHour: 13, targetMinute: 2, tz: tz) <= tolerance, "Dhuhr: \(h):\(m)")
            case .asr:     #expect(minutesDiff(pt.time, targetHour: 17, targetMinute: 25, tz: tz) <= tolerance, "Asr: \(h):\(m)")
            case .maghrib: #expect(minutesDiff(pt.time, targetHour: 21, targetMinute: 22, tz: tz) <= tolerance, "Maghrib: \(h):\(m)")
            default: break // Fajr/Isha may use fallback at high latitude in summer
            }
        }
    }

    @Test func londonJuneHighLatitudeTimesAreBoundedAndContinuous() {
        let tz = TimeZone(identifier: "Europe/London")!
        let loc = UserLocation(latitude: 51.5074, longitude: -0.1278, name: "London", timezoneIdentifier: "Europe/London")
        let dates = (20...22).map { makeDate(year: 2024, month: 6, day: $0, tz: tz) }
        let days = dates.map { PrayerTimeCalculator.calculate(date: $0, location: loc, method: .mwl) }
        let times = days.map { day in
            (day.times.first { $0.prayer == .fajr }!.time, day.times.first { $0.prayer == .sunrise }!.time,
             day.times.first { $0.prayer == .maghrib }!.time, day.times.first { $0.prayer == .isha }!.time)
        }
        for (fajr, sunrise, maghrib, isha) in times {
            #expect(fajr < sunrise)
            #expect(maghrib < isha)
            #expect(sunrise.timeIntervalSince(fajr) < 2 * 3600)
            #expect(isha.timeIntervalSince(maghrib) < 2 * 3600)
        }
        for index in 1..<times.count {
            #expect(abs(times[index].0.timeIntervalSince(times[index - 1].0) - 24 * 3600) < 45 * 60)
            #expect(abs(times[index].3.timeIntervalSince(times[index - 1].3) - 24 * 3600) < 45 * 60)
        }
        // AlAdhan, 21 June 2024, London, method=3 (MWL), latitudeAdjustmentMethod=2 (one
        // seventh of the night): Fajr 03:40, Sunrise 04:43, Maghrib 21:22, Isha 22:25.
        let center = times[1]
        #expect(minutesDiff(center.0, targetHour: 3, targetMinute: 40, tz: tz) <= 5)
        #expect(minutesDiff(center.1, targetHour: 4, targetMinute: 43, tz: tz) <= 5)
        #expect(minutesDiff(center.2, targetHour: 21, targetMinute: 22, tz: tz) <= 5)
        #expect(minutesDiff(center.3, targetHour: 22, targetMinute: 25, tz: tz) <= 5)
    }

    /// Mid-latitude summer keeps the angle times (no high-latitude limit below 48°).
    @Test func newYorkSummerUsesAngleTimes() {
        let tz = TimeZone(identifier: "America/New_York")!
        let loc = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")
        let result = PrayerTimeCalculator.calculate(date: makeDate(year: 2024, month: 6, day: 21, tz: tz), location: loc, method: .isna)
        // AlAdhan, 21 June 2024, method=2 (ISNA), angle based: Fajr 03:45, Isha 22:11.
        #expect(minutesDiff(result.times.first { $0.prayer == .fajr }!.time, targetHour: 3, targetMinute: 45, tz: tz) <= 3)
        #expect(minutesDiff(result.times.first { $0.prayer == .isha }!.time, targetHour: 22, targetMinute: 11, tz: tz) <= 3)
    }

    @Test func tehranMaghribUsesItsAngle() {
        let tz = TimeZone(identifier: "Asia/Tehran")!
        let date = makeDate(year: 2024, month: 3, day: 15, tz: tz)
        let loc = UserLocation(latitude: 35.6892, longitude: 51.3890, name: "Tehran", timezoneIdentifier: "Asia/Tehran")
        let result = PrayerTimeCalculator.calculate(date: date, location: loc, method: .tehran)
        let maghrib = result.times.first { $0.prayer == .maghrib }!.time
        // AlAdhan API method 7 for Tehran, 15 March 2024: sunset 18:12, Maghrib 18:30.
        #expect(minutesDiff(maghrib, targetHour: 18, targetMinute: 30, tz: tz) <= 4)
    }

    // MARK: - Sydney, southern hemisphere summer (verified against Aladhan API)

    @Test func sydneySouthernSummer() {
        let tz = TimeZone(identifier: "Australia/Sydney")!
        let date = makeDate(year: 2024, month: 12, day: 21, tz: tz)
        let loc = UserLocation(latitude: -33.8688, longitude: 151.2093, name: "Sydney", timezoneIdentifier: "Australia/Sydney")
        let result = PrayerTimeCalculator.calculate(date: date, location: loc, method: .mwl)

        let tolerance = 5
        for pt in result.times {
            let (h, m) = hourMinute(from: pt.time, tz: tz)
            switch pt.prayer {
            case .sunrise: #expect(minutesDiff(pt.time, targetHour: 5, targetMinute: 41, tz: tz) <= tolerance, "Sunrise: \(h):\(m)")
            case .dhuhr:   #expect(minutesDiff(pt.time, targetHour: 12, targetMinute: 53, tz: tz) <= tolerance, "Dhuhr: \(h):\(m)")
            case .maghrib: #expect(minutesDiff(pt.time, targetHour: 20, targetMinute: 6, tz: tz) <= tolerance, "Maghrib: \(h):\(m)")
            default: break
            }
        }
    }

    // MARK: - Hanafi vs Shafi'i Asr

    @Test func hanafiAsrIsLater() {
        let tz = TimeZone(identifier: "America/New_York")!
        let date = makeDate(year: 2024, month: 3, day: 15, tz: tz)
        let loc = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")

        let shafii = PrayerTimeCalculator.calculate(date: date, location: loc, method: .isna, asrFactor: 1)
        let hanafi = PrayerTimeCalculator.calculate(date: date, location: loc, method: .isna, asrFactor: 2)

        let shafiiAsr = shafii.times.first { $0.prayer == .asr }!.time
        let hanafiAsr = hanafi.times.first { $0.prayer == .asr }!.time
        #expect(hanafiAsr > shafiiAsr)
    }

    // MARK: - Umm Al-Qura uses minutes for Isha

    @Test func ummAlQuraIshaUsesMinutes() {
        let tz = TimeZone(identifier: "Asia/Riyadh")!
        let date = makeDate(year: 2024, month: 3, day: 15, tz: tz)
        let loc = UserLocation(latitude: 21.4225, longitude: 39.8262, name: "Mecca", timezoneIdentifier: "Asia/Riyadh")

        let result = PrayerTimeCalculator.calculate(date: date, location: loc, method: .makkah)
        let maghrib = result.times.first { $0.prayer == .maghrib }!.time
        let isha = result.times.first { $0.prayer == .isha }!.time
        let diff = isha.timeIntervalSince(maghrib) / 60
        #expect(abs(diff - 90) < 2, "Isha should be ~90 min after Maghrib for Umm Al-Qura, got \(diff)")
    }

    // MARK: - Different methods produce different Fajr

    @Test func differentMethodsDifferentFajr() {
        let tz = TimeZone(identifier: "America/New_York")!
        let date = makeDate(year: 2024, month: 3, day: 15, tz: tz)
        let loc = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")

        let isna = PrayerTimeCalculator.calculate(date: date, location: loc, method: .isna)
        let mwl = PrayerTimeCalculator.calculate(date: date, location: loc, method: .mwl)

        let isnaFajr = isna.times.first { $0.prayer == .fajr }!.time
        let mwlFajr = mwl.times.first { $0.prayer == .fajr }!.time
        #expect(isnaFajr != mwlFajr)
        #expect(mwlFajr < isnaFajr)
    }

    // MARK: - Julian Day

    @Test func julianDayKnownValue() {
        let jd = PrayerTimeCalculator.julianDay(year: 2000, month: 1, day: 1)
        #expect(abs(jd - 2451544.5) < 0.01)
    }
}
