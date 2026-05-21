import Foundation
import SwiftUI

enum PrayerName: String, CaseIterable, Codable, Sendable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    func displayName(on date: Date, calendar: Calendar = .current) -> String {
        if self == .dhuhr && calendar.component(.weekday, from: date) == 6 {
            return "Jumuah"
        }
        return displayName
    }

    var icon: String {
        switch self {
        case .fajr: return "sun.horizon"
        case .sunrise: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }

    var isActualPrayer: Bool {
        self != .sunrise
    }
}

struct PrayerTime: Sendable {
    let prayer: PrayerName
    let time: Date
}

struct DailyPrayerTimes: Sendable {
    let date: Date
    let times: [PrayerTime]
    let location: UserLocation
    let method: CalculationMethod

    func nextPrayer(after now: Date) -> PrayerTime? {
        times.first { $0.time > now }
    }

    func currentDisplayTime(after now: Date) -> PrayerTime? {
        let orderedTimes = times.sorted { $0.time < $1.time }
        for (index, prayerTime) in orderedTimes.enumerated() {
            let nextTime = index + 1 < orderedTimes.count ? orderedTimes[index + 1].time : nil
            if prayerTime.time <= now && (nextTime == nil || now < nextTime!) {
                return prayerTime.prayer.isActualPrayer ? prayerTime : nil
            }
        }
        return nil
    }

    func timeUntilNext(after now: Date) -> TimeInterval? {
        guard let next = nextPrayer(after: now) else { return nil }
        return next.time.timeIntervalSince(now)
    }

    func formattedTime(for prayer: PrayerName, timeZone: TimeZone) -> String? {
        guard let pt = times.first(where: { $0.prayer == prayer }) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone
        return formatter.string(from: pt.time)
    }
}
