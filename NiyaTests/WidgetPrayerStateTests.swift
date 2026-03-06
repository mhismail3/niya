import Testing
import Foundation
@testable import Niya

@Suite("WidgetPrayerState")
struct WidgetPrayerStateTests {
    private let cal = Calendar.current

    private func sampleData() -> WidgetPrayerData {
        let base = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: base)!
        func time(_ h: Int, _ m: Int, on d: Date = base) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: d)!
        }
        return WidgetPrayerData(
            computedAt: Date(),
            locationName: "Kirkland, WA",
            hijriDate: "4 Ramadan 1447 AH",
            prayers: [
                WidgetPrayer(name: "Fajr", abbreviation: "FJR", time: time(5, 19), icon: "sun.horizon", isActualPrayer: true),
                WidgetPrayer(name: "Sunrise", abbreviation: "SHR", time: time(6, 43), icon: "sunrise", isActualPrayer: false),
                WidgetPrayer(name: "Dhuhr", abbreviation: "DHR", time: time(12, 21), icon: "sun.max", isActualPrayer: true),
                WidgetPrayer(name: "Asr", abbreviation: "ASR", time: time(15, 24), icon: "sun.min", isActualPrayer: true),
                WidgetPrayer(name: "Maghrib", abbreviation: "MGB", time: time(17, 58), icon: "sunset", isActualPrayer: true),
                WidgetPrayer(name: "Isha", abbreviation: "ISH", time: time(19, 23), icon: "moon.stars", isActualPrayer: true),
            ],
            tomorrowPrayers: [
                WidgetPrayer(name: "Fajr", abbreviation: "FJR", time: time(5, 18, on: tomorrow), icon: "sun.horizon", isActualPrayer: true),
                WidgetPrayer(name: "Sunrise", abbreviation: "SHR", time: time(6, 42, on: tomorrow), icon: "sunrise", isActualPrayer: false),
                WidgetPrayer(name: "Dhuhr", abbreviation: "DHR", time: time(12, 21, on: tomorrow), icon: "sun.max", isActualPrayer: true),
                WidgetPrayer(name: "Asr", abbreviation: "ASR", time: time(15, 25, on: tomorrow), icon: "sun.min", isActualPrayer: true),
                WidgetPrayer(name: "Maghrib", abbreviation: "MGB", time: time(17, 59, on: tomorrow), icon: "sunset", isActualPrayer: true),
                WidgetPrayer(name: "Isha", abbreviation: "ISH", time: time(19, 24, on: tomorrow), icon: "moon.stars", isActualPrayer: true),
            ],
            latitude: 47.6769, longitude: -122.2060,
            timezoneIdentifier: "America/Los_Angeles",
            calculationMethod: "isna", asrFactor: 1
        )
    }

    @Test("3:00 AM — before Fajr")
    func beforeFajr() {
        let data = sampleData()
        let base = cal.startOfDay(for: Date())
        let time = cal.date(bySettingHour: 3, minute: 0, second: 0, of: base)!
        #expect(data.currentPrayer(at: time) == nil)
        #expect(data.nextPrayer(at: time)?.name == "Fajr")
    }

    @Test("5:30 AM — after Fajr, before Sunrise")
    func afterFajr() {
        let data = sampleData()
        let base = cal.startOfDay(for: Date())
        let time = cal.date(bySettingHour: 5, minute: 30, second: 0, of: base)!
        #expect(data.currentPrayer(at: time)?.name == "Fajr")
        #expect(data.nextPrayer(at: time)?.name == "Sunrise")
    }

    @Test("12:30 PM — after Dhuhr")
    func afterDhuhr() {
        let data = sampleData()
        let base = cal.startOfDay(for: Date())
        let time = cal.date(bySettingHour: 12, minute: 30, second: 0, of: base)!
        #expect(data.currentPrayer(at: time)?.name == "Dhuhr")
        #expect(data.nextPrayer(at: time)?.name == "Asr")
    }

    @Test("11:30 PM — after Isha")
    func afterIsha() {
        let data = sampleData()
        let base = cal.startOfDay(for: Date())
        let time = cal.date(bySettingHour: 23, minute: 30, second: 0, of: base)!
        #expect(data.currentPrayer(at: time)?.name == "Isha")
        #expect(data.nextPrayer(at: time)?.name == "Fajr")
    }

    @Test("11:59 PM — about to roll over")
    func aboutToRollOver() {
        let data = sampleData()
        let base = cal.startOfDay(for: Date())
        let time = cal.date(bySettingHour: 23, minute: 59, second: 0, of: base)!
        #expect(data.currentPrayer(at: time)?.name == "Isha")
        #expect(data.nextPrayer(at: time)?.name == "Fajr")
    }

    @Test("After tomorrow Fajr — nextPrayer is Sunrise")
    func afterTomorrowFajr() {
        let data = sampleData()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let time = cal.date(bySettingHour: 5, minute: 30, second: 0, of: tomorrow)!
        #expect(data.nextPrayer(at: time)?.name == "Sunrise")
    }

    @Test("At midnight — nextPrayer is tomorrow Fajr")
    func atMidnight() {
        let data = sampleData()
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        #expect(data.nextPrayer(at: midnight)?.name == "Fajr")
    }

    @Test("Progress bar fraction midday")
    func progressMidDay() {
        let data = sampleData()
        let base = cal.startOfDay(for: Date())
        let time = cal.date(bySettingHour: 12, minute: 21, second: 0, of: base)!
        let progress = data.dayProgress(at: time)
        #expect(progress > 0.3 && progress < 0.7)
    }

    @Test("PrayerTimeEntry prayerState")
    func prayerState() {
        let data = sampleData()
        let base = cal.startOfDay(for: Date())
        let time = cal.date(bySettingHour: 12, minute: 30, second: 0, of: base)!
        let entry = PrayerTimeEntry(date: time, data: data)

        #expect(entry.prayerState(data.prayers[0]) == .passed)   // Fajr
        #expect(entry.prayerState(data.prayers[2]) == .current)  // Dhuhr
        #expect(entry.prayerState(data.prayers[3]) == .next)     // Asr
        #expect(entry.prayerState(data.prayers[5]) == .future)   // Isha
    }

    @Test("Mock data is valid")
    func mockData() {
        let mock = WidgetPrayerData.mock
        #expect(mock.prayers.count == 6)
        #expect(mock.tomorrowPrayers.count == 6)
        #expect(!mock.locationName.isEmpty)
        #expect(!mock.hijriDate.isEmpty)
    }
}
