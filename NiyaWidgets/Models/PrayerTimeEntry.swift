import WidgetKit

struct PrayerTimeEntry: TimelineEntry {
    let date: Date
    let data: WidgetPrayerData
    let isPlaceholder: Bool
    let isFallback: Bool

    init(date: Date, data: WidgetPrayerData, isPlaceholder: Bool = false, isFallback: Bool = false) {
        self.date = date
        self.data = data
        self.isPlaceholder = isPlaceholder
        self.isFallback = isFallback
    }

    var currentPrayer: WidgetPrayer? {
        data.currentPrayer(at: date)
    }

    var nextPrayer: WidgetPrayer? {
        data.nextPrayer(at: date)
    }

    var dayProgress: Double {
        data.dayProgress(at: date)
    }

    func prayerState(_ prayer: WidgetPrayer) -> PrayerState {
        if let current = currentPrayer, current.name == prayer.name {
            return .current
        }
        if let next = nextPrayer, next.name == prayer.name {
            return .next
        }
        if prayer.time <= date {
            return .passed
        }
        return .future
    }

    enum PrayerState {
        case current, next, passed, future
    }
}
