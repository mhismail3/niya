import Testing
import Foundation
@testable import Niya

@Suite("WidgetDataWriter")
struct WidgetDataWriterTests {
    private let suiteName = "group.com.niya.mobile.test.\(UUID().uuidString)"

    private func makeWriter() -> (WidgetDataWriter, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let writer = WidgetDataWriter(defaults: defaults)
        return (writer, defaults)
    }

    @Test("Write and read round-trip")
    func writeReadRoundTrip() {
        let (writer, _) = makeWriter()
        let location = UserLocation.mecca
        let today = PrayerTimeCalculator.calculate(date: Date(), location: location, method: .isna)
        writer.write(today: today, tomorrow: nil, location: location)
        let data = writer.read()
        #expect(data != nil)
        #expect(data?.prayers.count == 6)
        #expect(data?.locationName == "Mecca, Saudi Arabia")
        #expect(data?.calculationMethod == "isna")
    }

    @Test("Read returns nil when no data stored")
    func readReturnsNilWhenEmpty() {
        let (writer, _) = makeWriter()
        let data = writer.read()
        #expect(data == nil)
    }

    @Test("Read returns nil for corrupted data")
    func readReturnsNilForCorrupted() {
        let (writer, defaults) = makeWriter()
        defaults.set(Data("garbage".utf8), forKey: SharedConstants.widgetPrayerDataKey)
        let data = writer.read()
        #expect(data == nil)
    }

    @Test("isStale returns true for old data")
    func stalenessCheck() {
        let oldDate = Calendar.current.date(byAdding: .hour, value: -27, to: Date())!
        let data = WidgetPrayerData(
            computedAt: oldDate,
            locationName: "Test",
            hijriDate: "1 Muharram 1447 AH",
            prayers: [],
            tomorrowPrayers: [],
            latitude: 0, longitude: 0,
            timezoneIdentifier: "UTC",
            calculationMethod: "isna",
            asrFactor: 1
        )
        #expect(WidgetDataWriter.isStale(data) == true)
    }

    @Test("isStale returns false for recent data")
    func notStale() {
        let data = WidgetPrayerData(
            computedAt: Date(),
            locationName: "Test",
            hijriDate: "1 Muharram 1447 AH",
            prayers: [],
            tomorrowPrayers: [],
            latitude: 0, longitude: 0,
            timezoneIdentifier: "UTC",
            calculationMethod: "isna",
            asrFactor: 1
        )
        #expect(WidgetDataWriter.isStale(data) == false)
    }

    @Test("isStale returns true when stored day is no longer today")
    func staleAfterMidnight() {
        let tz = TimeZone(identifier: "America/New_York")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let lateEvening = cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 23))!
        let nextMorning = cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 8))!
        let location = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "NY", timezoneIdentifier: tz.identifier)
        let today = PrayerTimeCalculator.calculate(date: lateEvening, location: location, method: .isna)
        let data = WidgetPrayerData.from(today: today, tomorrow: nil, location: location, hijriDate: "")
        let computed = WidgetPrayerData(
            computedAt: lateEvening, locationName: data.locationName, hijriDate: data.hijriDate,
            prayers: data.prayers, tomorrowPrayers: data.tomorrowPrayers,
            latitude: data.latitude, longitude: data.longitude, timezoneIdentifier: data.timezoneIdentifier,
            calculationMethod: data.calculationMethod, asrFactor: data.asrFactor
        )
        #expect(WidgetDataWriter.isStale(computed, now: lateEvening.addingTimeInterval(1800)) == false)
        #expect(WidgetDataWriter.isStale(computed, now: nextMorning) == true)
    }

    @Test("Prayer time formatter honors 12/24-hour locale")
    func prayerTimeFormatterHonorsLocale() {
        let utc = TimeZone(identifier: "UTC")!
        let date = Date(timeIntervalSince1970: 15 * 3600 + 5 * 60)
        #expect(DateFormatter.prayerTime(timeZone: utc, locale: Locale(identifier: "en_GB")).string(from: date) == "15:05")
        let us = DateFormatter.prayerTime(timeZone: utc, locale: Locale(identifier: "en_US")).string(from: date)
        #expect(us.hasPrefix("3:05") && us.hasSuffix("PM"))
        #expect(DateFormatter.prayerTime(timeZone: utc, includePeriod: false, locale: Locale(identifier: "en_US")).string(from: date) == "3:05")
    }

    @Test("Hijri date is included in written data")
    func hijriDatePresent() {
        let (writer, _) = makeWriter()
        let location = UserLocation.mecca
        let today = PrayerTimeCalculator.calculate(date: Date(), location: location, method: .isna)
        writer.write(today: today, tomorrow: nil, location: location)
        let data = writer.read()
        #expect(data?.hijriDate.isEmpty == false)
        #expect(data?.hijriDate.contains("AH") == true)
    }

    @Test("asrFactor is preserved")
    func asrFactorPreserved() {
        let (writer, _) = makeWriter()
        let location = UserLocation.mecca
        let today = PrayerTimeCalculator.calculate(date: Date(), location: location, method: .isna, asrFactor: 2)
        writer.write(today: today, tomorrow: nil, location: location, asrFactor: 2)
        let data = writer.read()
        #expect(data?.asrFactor == 2)
    }
}
