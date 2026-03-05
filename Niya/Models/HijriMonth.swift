import Foundation

struct HijriMonth: Hashable, Sendable {
    let year: Int
    let month: Int

    private static let hijriCal = Calendar(identifier: .islamicUmmAlQura)

    var displayName: String {
        (month >= 1 && month <= 12) ? HijriFormatter.monthNames[month - 1] : "Unknown"
    }

    var dayCount: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = Self.hijriCal.date(from: comps),
              let range = Self.hijriCal.range(of: .day, in: .month, for: date) else {
            return 30
        }
        return range.count
    }

    func gregorianDate(forDay day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Self.hijriCal.date(from: comps) ?? Date()
    }

    var gregorianDateRange: (start: Date, end: Date) {
        (gregorianDate(forDay: 1), gregorianDate(forDay: dayCount))
    }

    var next: HijriMonth {
        month == 12 ? HijriMonth(year: year + 1, month: 1) : HijriMonth(year: year, month: month + 1)
    }

    var previous: HijriMonth {
        month == 1 ? HijriMonth(year: year - 1, month: 12) : HijriMonth(year: year, month: month - 1)
    }

    var firstWeekday: Int {
        let date = gregorianDate(forDay: 1)
        return Calendar(identifier: .gregorian).component(.weekday, from: date)
    }

    static func current() -> HijriMonth {
        let comps = hijriCal.dateComponents([.year, .month], from: Date())
        return HijriMonth(year: comps.year ?? 1447, month: comps.month ?? 1)
    }
}
