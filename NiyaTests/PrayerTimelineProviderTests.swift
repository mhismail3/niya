import Testing
import Foundation
@testable import Niya

@Suite("PrayerTimelineProvider")
struct PrayerTimelineProviderTests {
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

    @Test("makeEntries generates entries in chronological order")
    func entriesChronological() {
        let data = sampleData()
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: now)
        for i in 1..<entries.count {
            #expect(entries[i].date >= entries[i - 1].date)
        }
    }

    @Test("makeEntries includes now entry")
    func entriesIncludeNow() {
        let data = sampleData()
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: now)
        #expect(entries.first?.date == now)
    }

    @Test("makeEntries includes future prayer entries")
    func entriesIncludeFuturePrayers() {
        let data = sampleData()
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: now)
        #expect(entries.count >= 4)
    }

    @Test("makeEntries includes midnight rollover")
    func entriesIncludeMidnight() {
        let data = sampleData()
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: now)
        let tomorrowStart = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
        let hasMidnight = entries.contains { cal.isDate($0.date, inSameDayAs: tomorrowStart) && cal.component(.hour, from: $0.date) == 0 }
        #expect(hasMidnight == true)
    }

    @Test("makeEntries has no duplicate dates")
    func noDuplicates() {
        let data = sampleData()
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: now)
        let timestamps = entries.map { $0.date.timeIntervalSinceReferenceDate }
        let uniqueTimestamps = Set(timestamps)
        #expect(timestamps.count == uniqueTimestamps.count)
    }

    @Test("loadOrComputeData returns valid data")
    func loadOrComputeDefault() {
        let (data, _) = PrayerTimelineProvider.loadOrComputeData()
        #expect(data.prayers.count == 6)
        #expect(!data.locationName.isEmpty)
    }

    @Test("Entry before Fajr - nextPrayer is Fajr")
    func entryBeforeFajr() {
        let data = sampleData()
        let earlyMorning = cal.date(bySettingHour: 3, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entry = PrayerTimeEntry(date: earlyMorning, data: data)
        #expect(entry.nextPrayer?.name == "Fajr")
        #expect(entry.currentPrayer == nil)
    }

    @Test("Entry after Isha - nextPrayer is tomorrow Fajr")
    func entryAfterIsha() {
        let data = sampleData()
        let lateNight = cal.date(bySettingHour: 23, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entry = PrayerTimeEntry(date: lateNight, data: data)
        #expect(entry.nextPrayer?.name == "Fajr")
        #expect(entry.currentPrayer?.name == "Isha")
    }

    @Test("makeEntries includes tomorrow prayer entries")
    func entriesIncludeTomorrowPrayers() {
        let data = sampleData()
        let lateNight = cal.date(bySettingHour: 22, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: lateNight)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let tomorrowEntries = entries.filter { cal.isDate($0.date, inSameDayAs: tomorrow) && cal.component(.hour, from: $0.date) > 0 }
        #expect(tomorrowEntries.count >= 6)
    }

    @Test("makeEntries at midnight includes tomorrow entries")
    func entriesAtMidnightIncludeTomorrow() {
        let data = sampleData()
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!)
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: midnight)
        #expect(entries.count >= 7)
    }

    @Test("makeEntries late evening - entry exists for each transition point")
    func entriesLateEveningTransitions() {
        let data = sampleData()
        let lateEvening = cal.date(bySettingHour: 20, minute: 0, second: 0, of: cal.startOfDay(for: Date()))!
        let entries = PrayerTimelineProvider.makeEntries(from: data, now: lateEvening)
        #expect(entries.count >= 8)
    }

    @Test("Entry at tomorrow Fajr time - nextPrayer transitions to Sunrise")
    func entryAtTomorrowFajrTransitions() {
        let data = sampleData()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let fajrTime = cal.date(bySettingHour: 5, minute: 18, second: 0, of: tomorrow)!
        let entry = PrayerTimeEntry(date: fajrTime, data: data)
        #expect(entry.nextPrayer?.name == "Sunrise")
    }
}
