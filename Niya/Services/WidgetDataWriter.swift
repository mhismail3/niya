import Foundation
import WidgetKit

struct WidgetDataWriter {
    static let shared = WidgetDataWriter()
    private nonisolated(unsafe) let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: SharedConstants.appGroupId)) {
        self.defaults = defaults
    }

    func write(today: DailyPrayerTimes, tomorrow: DailyPrayerTimes?, location: UserLocation, asrFactor: Int = 1) {
        let hijri = HijriFormatter.format(date: Date())
        let data = WidgetPrayerData.from(today: today, tomorrow: tomorrow, location: location, hijriDate: hijri, asrFactor: asrFactor)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults?.set(encoded, forKey: SharedConstants.widgetPrayerDataKey)
    }

    func read() -> WidgetPrayerData? {
        guard let data = defaults?.data(forKey: SharedConstants.widgetPrayerDataKey) else { return nil }
        return try? JSONDecoder().decode(WidgetPrayerData.self, from: data)
    }

    static func isStale(_ data: WidgetPrayerData, now: Date = Date()) -> Bool {
        let hours = now.timeIntervalSince(data.computedAt) / 3600
        return hours > WidgetConstants.stalenessThresholdHours
    }

    func reloadTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConstants.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConstants.lockWidgetKind)
    }
}
