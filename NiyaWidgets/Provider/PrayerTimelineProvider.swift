import WidgetKit

struct PrayerTimelineProvider: TimelineProvider {
    typealias Entry = PrayerTimeEntry

    func placeholder(in context: Context) -> PrayerTimeEntry {
        PrayerTimeEntry(date: Date(), data: .mock, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerTimeEntry) -> Void) {
        let (data, isFallback) = Self.loadOrComputeData()
        completion(PrayerTimeEntry(date: Date(), data: data, isFallback: isFallback))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimeEntry>) -> Void) {
        let (data, isFallback) = Self.loadOrComputeData()
        let now = Date()
        let entries = Self.makeEntries(from: data, now: now, isFallback: isFallback)
        // Refresh after today's last prayer + 30 min — ensures fresh data each evening
        // rather than running a stale 2-day timeline.
        let todayLastPrayer = data.prayers.last?.time ?? now
        let refreshBase = max(todayLastPrayer, now)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: refreshBase)
            ?? Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    static func loadOrComputeData() -> (WidgetPrayerData, isFallback: Bool) {
        let reader = WidgetDataWriter()
        guard let data = reader.read() else {
            return (recompute(location: .mecca, method: .isna, asrFactor: 1), isFallback: true)
        }
        guard WidgetDataWriter.isStale(data) else { return (data, isFallback: false) }
        let location = UserLocation(
            latitude: data.latitude,
            longitude: data.longitude,
            name: data.locationName,
            timezoneIdentifier: data.timezoneIdentifier
        )
        let method = CalculationMethod(rawValue: data.calculationMethod) ?? .isna
        return (recompute(location: location, method: method, asrFactor: data.asrFactor), isFallback: false)
    }

    private static func recompute(location: UserLocation, method: CalculationMethod, asrFactor: Int) -> WidgetPrayerData {
        let now = Date()
        let today = PrayerTimeCalculator.calculate(date: now, location: location, method: method, asrFactor: asrFactor)
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrow = PrayerTimeCalculator.calculate(date: tomorrowDate, location: location, method: method, asrFactor: asrFactor)
        return WidgetPrayerData.from(today: today, tomorrow: tomorrow, location: location, hijriDate: HijriFormatter.format(date: now), asrFactor: asrFactor)
    }

    static func makeEntries(from data: WidgetPrayerData, now: Date, isFallback: Bool = false) -> [PrayerTimeEntry] {
        var entries: [PrayerTimeEntry] = []
        let cal = Calendar.current

        entries.append(PrayerTimeEntry(date: now, data: data, isFallback: isFallback))

        for prayer in data.prayers where prayer.time > now {
            entries.append(PrayerTimeEntry(date: prayer.time, data: data, isFallback: isFallback))
        }

        // Add tomorrow entries, but drop the last prayer — at that entry time,
        // nextPrayer would need day-after-tomorrow data we don't have.
        let tomorrowFuture = data.tomorrowPrayers.filter { $0.time > now }
        for prayer in tomorrowFuture.dropLast() {
            entries.append(PrayerTimeEntry(date: prayer.time, data: data, isFallback: isFallback))
        }

        if let nextDay = cal.date(byAdding: .day, value: 1, to: now),
           let midnight = cal.date(bySettingHour: 0, minute: 0, second: 0, of: nextDay) {
            entries.append(PrayerTimeEntry(date: midnight, data: data, isFallback: isFallback))
        }

        entries.sort { $0.date < $1.date }

        var seen = Set<TimeInterval>()
        entries = entries.filter { seen.insert($0.date.timeIntervalSinceReferenceDate).inserted }

        return entries
    }
}
