import Foundation

struct WidgetPrayer: Codable, Sendable, Equatable {
    let name: String
    let abbreviation: String
    let time: Date
    let icon: String
    let isActualPrayer: Bool
}

struct WidgetPrayerData: Codable, Sendable, Equatable {
    let computedAt: Date
    let locationName: String
    let hijriDate: String
    let prayers: [WidgetPrayer]
    let tomorrowPrayers: [WidgetPrayer]

    let latitude: Double
    let longitude: Double
    let timezoneIdentifier: String
    let calculationMethod: String
    let asrFactor: Int

    func currentPrayer(at date: Date) -> WidgetPrayer? {
        let actual = prayers.filter { $0.isActualPrayer }
        for (i, prayer) in actual.enumerated() {
            let nextTime = i + 1 < actual.count ? actual[i + 1].time : nil
            if prayer.time <= date && (nextTime == nil || date < nextTime!) {
                return prayer
            }
        }
        return nil
    }

    func nextPrayer(at date: Date) -> WidgetPrayer? {
        if let next = prayers.first(where: { $0.time > date }) {
            return next
        }
        if let next = tomorrowPrayers.first(where: { $0.time > date }) {
            return next
        }
        // Stale timeline fallback: all tomorrow prayers are past — return first tomorrow prayer.
        // Shows briefly until timeline refresh; avoids blank widget.
        return tomorrowPrayers.first
    }

    func dayProgress(at date: Date) -> Double {
        guard let first = prayers.first, let last = prayers.last else { return 0 }
        let total = last.time.timeIntervalSince(first.time)
        guard total > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(first.time)
        return max(0, min(1, elapsed / total))
    }

    static func abbreviation(for prayerName: PrayerName, on date: Date, calendar: Calendar = .current) -> String {
        if prayerName == .dhuhr && calendar.component(.weekday, from: date) == 6 {
            return "JMH"
        }
        switch prayerName {
        case .fajr: return "FJR"
        case .sunrise: return "SHR"
        case .dhuhr: return "DHR"
        case .asr: return "ASR"
        case .maghrib: return "MGB"
        case .isha: return "ISH"
        }
    }

    static func from(
        today: DailyPrayerTimes,
        tomorrow: DailyPrayerTimes?,
        location: UserLocation,
        hijriDate: String,
        asrFactor: Int = 1
    ) -> WidgetPrayerData {
        WidgetPrayerData(
            computedAt: Date(),
            locationName: location.name,
            hijriDate: hijriDate,
            prayers: today.times.map { pt in
                WidgetPrayer(
                    name: pt.prayer.displayName(on: today.date),
                    abbreviation: abbreviation(for: pt.prayer, on: today.date),
                    time: pt.time,
                    icon: pt.prayer.icon,
                    isActualPrayer: pt.prayer.isActualPrayer
                )
            },
            tomorrowPrayers: {
                let day = tomorrow?.date ?? today.date
                return (tomorrow?.times ?? []).map { pt in
                    WidgetPrayer(
                        name: pt.prayer.displayName(on: day),
                        abbreviation: abbreviation(for: pt.prayer, on: day),
                        time: pt.time,
                        icon: pt.prayer.icon,
                        isActualPrayer: pt.prayer.isActualPrayer
                    )
                }
            }(),
            latitude: location.latitude,
            longitude: location.longitude,
            timezoneIdentifier: location.timezoneIdentifier,
            calculationMethod: today.method.rawValue,
            asrFactor: asrFactor
        )
    }

    static let mock: WidgetPrayerData = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func time(_ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: today)!
        }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        return WidgetPrayerData(
            computedAt: Date(),
            locationName: "Kirkland, WA",
            hijriDate: HijriFormatter.format(date: Date()),
            prayers: [
                WidgetPrayer(name: "Fajr", abbreviation: "FJR", time: time(5, 19), icon: "sun.horizon", isActualPrayer: true),
                WidgetPrayer(name: "Sunrise", abbreviation: "SHR", time: time(6, 43), icon: "sunrise", isActualPrayer: false),
                WidgetPrayer(name: "Dhuhr", abbreviation: "DHR", time: time(12, 21), icon: "sun.max", isActualPrayer: true),
                WidgetPrayer(name: "Asr", abbreviation: "ASR", time: time(15, 24), icon: "sun.min", isActualPrayer: true),
                WidgetPrayer(name: "Maghrib", abbreviation: "MGB", time: time(17, 58), icon: "sunset", isActualPrayer: true),
                WidgetPrayer(name: "Isha", abbreviation: "ISH", time: time(19, 23), icon: "moon.stars", isActualPrayer: true),
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
    }()
}
