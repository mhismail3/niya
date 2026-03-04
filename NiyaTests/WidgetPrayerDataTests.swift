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
        #expect(decoded.tomorrowPrayers.count == 1)
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

    @Test("Abbreviation static method")
    func staticAbbreviation() {
        #expect(WidgetPrayerData.abbreviation(for: .fajr) == "FJR")
        #expect(WidgetPrayerData.abbreviation(for: .sunrise) == "SHR")
        #expect(WidgetPrayerData.abbreviation(for: .dhuhr) == "DHR")
        #expect(WidgetPrayerData.abbreviation(for: .asr) == "ASR")
        #expect(WidgetPrayerData.abbreviation(for: .maghrib) == "MGB")
        #expect(WidgetPrayerData.abbreviation(for: .isha) == "ISH")
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
