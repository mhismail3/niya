import Testing
import Foundation
@testable import Niya

@Suite("WidgetPrayerData")
struct WidgetPrayerDataTests {
    private let cal = Calendar.current

    private func makeDate(hour: Int, minute: Int, on baseDate: Date = Date()) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)!
    }

    private func sampleData(baseDate: Date = Date()) -> WidgetPrayerData {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: baseDate)!
        return WidgetPrayerData(
            computedAt: baseDate,
            locationName: "Kirkland, WA",
            hijriDate: "4 Ramadan 1447 AH",
            prayers: [
                WidgetPrayer(name: "Fajr", abbreviation: "FJR", time: makeDate(hour: 5, minute: 19, on: baseDate), icon: "sun.horizon", isActualPrayer: true),
                WidgetPrayer(name: "Sunrise", abbreviation: "SHR", time: makeDate(hour: 6, minute: 43, on: baseDate), icon: "sunrise", isActualPrayer: false),
                WidgetPrayer(name: "Dhuhr", abbreviation: "DHR", time: makeDate(hour: 12, minute: 21, on: baseDate), icon: "sun.max", isActualPrayer: true),
                WidgetPrayer(name: "Asr", abbreviation: "ASR", time: makeDate(hour: 15, minute: 24, on: baseDate), icon: "sun.min", isActualPrayer: true),
                WidgetPrayer(name: "Maghrib", abbreviation: "MGB", time: makeDate(hour: 17, minute: 58, on: baseDate), icon: "sunset", isActualPrayer: true),
                WidgetPrayer(name: "Isha", abbreviation: "ISH", time: makeDate(hour: 19, minute: 23, on: baseDate), icon: "moon.stars", isActualPrayer: true),
            ],
            tomorrowPrayers: [
                WidgetPrayer(name: "Fajr", abbreviation: "FJR", time: cal.date(bySettingHour: 5, minute: 18, second: 0, of: tomorrow)!, icon: "sun.horizon", isActualPrayer: true),
                WidgetPrayer(name: "Sunrise", abbreviation: "SHR", time: cal.date(bySettingHour: 6, minute: 42, second: 0, of: tomorrow)!, icon: "sunrise", isActualPrayer: false),
                WidgetPrayer(name: "Dhuhr", abbreviation: "DHR", time: cal.date(bySettingHour: 12, minute: 21, second: 0, of: tomorrow)!, icon: "sun.max", isActualPrayer: true),
                WidgetPrayer(name: "Asr", abbreviation: "ASR", time: cal.date(bySettingHour: 15, minute: 25, second: 0, of: tomorrow)!, icon: "sun.min", isActualPrayer: true),
                WidgetPrayer(name: "Maghrib", abbreviation: "MGB", time: cal.date(bySettingHour: 17, minute: 59, second: 0, of: tomorrow)!, icon: "sunset", isActualPrayer: true),
                WidgetPrayer(name: "Isha", abbreviation: "ISH", time: cal.date(bySettingHour: 19, minute: 24, second: 0, of: tomorrow)!, icon: "moon.stars", isActualPrayer: true),
            ],
            latitude: 47.6769,
            longitude: -122.2060,
            timezoneIdentifier: "America/Los_Angeles",
            calculationMethod: "isna",
            asrFactor: 1
        )
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let data = sampleData()
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(WidgetPrayerData.self, from: encoded)
        #expect(decoded.locationName == data.locationName)
        #expect(decoded.hijriDate == data.hijriDate)
        #expect(decoded.prayers.count == 6)
        #expect(decoded.tomorrowPrayers.count == 6)
        #expect(decoded.latitude == data.latitude)
        #expect(decoded.calculationMethod == "isna")
        #expect(decoded.asrFactor == 1)
    }

    @Test("All 6 prayers present with correct abbreviations")
    func abbreviationMapping() {
        let data = sampleData()
        let abbrevs = data.prayers.map(\.abbreviation)
        #expect(abbrevs == ["FJR", "SHR", "DHR", "ASR", "MGB", "ISH"])
    }

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func fixedDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("Abbreviation static method on non-Friday")
    func staticAbbreviation() {
        // 2026-03-28 is a Saturday
        let saturday = fixedDate(2026, 3, 28)
        #expect(WidgetPrayerData.abbreviation(for: .fajr, on: saturday, calendar: utcCalendar) == "FJR")
        #expect(WidgetPrayerData.abbreviation(for: .sunrise, on: saturday, calendar: utcCalendar) == "SHR")
        #expect(WidgetPrayerData.abbreviation(for: .dhuhr, on: saturday, calendar: utcCalendar) == "DHR")
        #expect(WidgetPrayerData.abbreviation(for: .asr, on: saturday, calendar: utcCalendar) == "ASR")
        #expect(WidgetPrayerData.abbreviation(for: .maghrib, on: saturday, calendar: utcCalendar) == "MGB")
        #expect(WidgetPrayerData.abbreviation(for: .isha, on: saturday, calendar: utcCalendar) == "ISH")
    }

    @Test("Abbreviation returns JMH for dhuhr on Friday")
    func abbreviationDhuhrFriday() {
        // 2026-03-27 is a Friday
        let friday = fixedDate(2026, 3, 27)
        #expect(WidgetPrayerData.abbreviation(for: .dhuhr, on: friday, calendar: utcCalendar) == "JMH")
    }

    @Test("Abbreviation returns FJR for fajr on Friday")
    func abbreviationFajrFriday() {
        let friday = fixedDate(2026, 3, 27)
        #expect(WidgetPrayerData.abbreviation(for: .fajr, on: friday, calendar: utcCalendar) == "FJR")
    }

    @Test("currentPrayer at midday returns Dhuhr")
    func currentPrayerMidday() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let noon = makeDate(hour: 12, minute: 30, on: base)
        let current = data.currentPrayer(at: noon)
        #expect(current?.name == "Dhuhr")
    }

    @Test("currentPrayer before Fajr returns nil")
    func currentPrayerBeforeFajr() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let earlyMorning = makeDate(hour: 3, minute: 0, on: base)
        let current = data.currentPrayer(at: earlyMorning)
        #expect(current == nil)
    }

    @Test("nextPrayer at midday returns Asr")
    func nextPrayerMidday() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let noon = makeDate(hour: 12, minute: 30, on: base)
        let next = data.nextPrayer(at: noon)
        #expect(next?.name == "Asr")
    }

    @Test("nextPrayer before Fajr returns Fajr")
    func nextPrayerBeforeFajr() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let earlyMorning = makeDate(hour: 3, minute: 0, on: base)
        let next = data.nextPrayer(at: earlyMorning)
        #expect(next?.name == "Fajr")
    }

    @Test("All prayers passed returns tomorrow Fajr")
    func allPrayersPassedReturnsTomorrow() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let lateNight = makeDate(hour: 23, minute: 30, on: base)
        let next = data.nextPrayer(at: lateNight)
        #expect(next?.name == "Fajr")
        #expect(next?.abbreviation == "FJR")
    }

    @Test("dayProgress at start returns 0")
    func dayProgressStart() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let beforeFajr = makeDate(hour: 4, minute: 0, on: base)
        let progress = data.dayProgress(at: beforeFajr)
        #expect(progress == 0)
    }

    @Test("dayProgress at end returns 1")
    func dayProgressEnd() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let afterIsha = makeDate(hour: 22, minute: 0, on: base)
        let progress = data.dayProgress(at: afterIsha)
        #expect(progress == 1)
    }

    @Test("from() factory method")
    func factoryMethod() {
        let location = UserLocation.mecca
        let today = PrayerTimeCalculator.calculate(date: Date(), location: location, method: .isna)
        let data = WidgetPrayerData.from(today: today, tomorrow: nil, location: location, hijriDate: "1 Muharram 1447 AH")
        #expect(data.prayers.count == 6)
        #expect(data.locationName == "Mecca, Saudi Arabia")
        #expect(data.hijriDate == "1 Muharram 1447 AH")
        #expect(data.tomorrowPrayers.isEmpty)
    }

    @Test("SF Symbol icons correct")
    func sfSymbolIcons() {
        let data = sampleData()
        let icons = data.prayers.map(\.icon)
        #expect(icons == ["sun.horizon", "sunrise", "sun.max", "sun.min", "sunset", "moon.stars"])
    }

    @Test("nextPrayer after tomorrow Fajr returns tomorrow Sunrise")
    func nextPrayerAfterTomorrowFajr() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: base)!
        let afterFajr = cal.date(bySettingHour: 5, minute: 30, second: 0, of: tomorrow)!
        let next = data.nextPrayer(at: afterFajr)
        #expect(next?.name == "Sunrise")
    }

    @Test("nextPrayer at exactly tomorrow Fajr time returns tomorrow Sunrise")
    func nextPrayerAtExactlyTomorrowFajr() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: base)!
        let fajrTime = cal.date(bySettingHour: 5, minute: 18, second: 0, of: tomorrow)!
        let next = data.nextPrayer(at: fajrTime)
        #expect(next?.name == "Sunrise")
    }

    @Test("nextPrayer at midnight returns tomorrow Fajr")
    func nextPrayerAtMidnight() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let midnight = cal.date(byAdding: .day, value: 1, to: base)!
        let next = data.nextPrayer(at: midnight)
        #expect(next?.name == "Fajr")
    }

    @Test("nextPrayer after all tomorrow prayers falls back to first tomorrow prayer")
    func nextPrayerAfterAllTomorrow() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: base)!
        let lateNextDay = cal.date(bySettingHour: 23, minute: 59, second: 0, of: tomorrow)!
        let next = data.nextPrayer(at: lateNextDay)
        #expect(next != nil)
        #expect(next?.name == "Fajr")
    }

    @Test("nextPrayer with empty tomorrowPrayers returns nil after today")
    func nextPrayerEmptyTomorrow() {
        let base = cal.startOfDay(for: Date())
        let data = WidgetPrayerData(
            computedAt: base,
            locationName: "Test",
            hijriDate: "Test",
            prayers: [
                WidgetPrayer(name: "Fajr", abbreviation: "FJR", time: makeDate(hour: 5, minute: 0, on: base), icon: "sun.horizon", isActualPrayer: true),
            ],
            tomorrowPrayers: [],
            latitude: 0, longitude: 0,
            timezoneIdentifier: "UTC",
            calculationMethod: "isna",
            asrFactor: 1
        )
        let afterAll = makeDate(hour: 23, minute: 0, on: base)
        #expect(data.nextPrayer(at: afterAll) == nil)
    }

    @Test("nextPrayer never returns nil when tomorrowPrayers exist")
    func nextPrayerNeverNilWithTomorrow() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: base)!
        let tomorrowIsha = cal.date(bySettingHour: 19, minute: 24, second: 0, of: tomorrow)!
        #expect(data.nextPrayer(at: tomorrowIsha) != nil)
    }

    @Test("nextPrayer just after today Isha returns tomorrow Fajr")
    func nextPrayerJustAfterIsha() {
        let base = cal.startOfDay(for: Date())
        let data = sampleData(baseDate: base)
        let justAfterIsha = makeDate(hour: 19, minute: 24, on: base)
        let next = data.nextPrayer(at: justAfterIsha)
        #expect(next?.name == "Fajr")
    }

    @Test("nextPrayer with empty tomorrowPrayers AND all today passed returns nil")
    func nextPrayerEmptyTomorrowAllPassed() {
        let base = cal.startOfDay(for: Date())
        let data = WidgetPrayerData(
            computedAt: base, locationName: "Test", hijriDate: "Test",
            prayers: [WidgetPrayer(name: "Fajr", abbreviation: "FJR", time: makeDate(hour: 5, minute: 0, on: base), icon: "sun.horizon", isActualPrayer: true)],
            tomorrowPrayers: [],
            latitude: 0, longitude: 0, timezoneIdentifier: "UTC", calculationMethod: "isna", asrFactor: 1
        )
        #expect(data.nextPrayer(at: makeDate(hour: 23, minute: 0, on: base)) == nil)
    }

    @Test("isActualPrayer - sunrise is false, others true")
    func isActualPrayer() {
        let data = sampleData()
        #expect(data.prayers[0].isActualPrayer == true)  // Fajr
        #expect(data.prayers[1].isActualPrayer == false)  // Sunrise
        #expect(data.prayers[2].isActualPrayer == true)  // Dhuhr
        #expect(data.prayers[3].isActualPrayer == true)  // Asr
        #expect(data.prayers[4].isActualPrayer == true)  // Maghrib
        #expect(data.prayers[5].isActualPrayer == true)  // Isha
    }
}
