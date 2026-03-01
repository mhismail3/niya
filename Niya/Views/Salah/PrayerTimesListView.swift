import SwiftUI

struct PrayerTimesListView: View {
    let times: DailyPrayerTimes
    let timeZone: TimeZone
    var showAll: Bool = true
    var compact: Bool = false

    private var now: Date { Date() }

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            if showAll {
                hijriDateHeader
            }

            ForEach(displayTimes, id: \.prayer) { pt in
                if showAll || isUpcoming(pt) || isNext(pt) {
                    prayerRow(pt)
                }
            }
        }
    }

    private var displayTimes: [PrayerTime] {
        showAll ? times.times : Array(upcomingTimes.prefix(3))
    }

    private var upcomingTimes: [PrayerTime] {
        let next = times.nextPrayer(after: now)
        guard let nextPrayer = next else { return [] }
        let idx = times.times.firstIndex(where: { $0.prayer == nextPrayer.prayer }) ?? 0
        return Array(times.times[idx...])
    }

    private func isNext(_ pt: PrayerTime) -> Bool {
        times.nextPrayer(after: now)?.prayer == pt.prayer
    }

    private func isUpcoming(_ pt: PrayerTime) -> Bool {
        pt.time > now
    }

    private func hasPassed(_ pt: PrayerTime) -> Bool {
        pt.time <= now
    }

    private func prayerRow(_ pt: PrayerTime) -> some View {
        HStack {
            Image(systemName: pt.prayer.icon)
                .frame(width: 24)
                .foregroundStyle(isNext(pt) ? Color.niyaTeal : hasPassed(pt) ? Color.niyaSecondary : Color.niyaText)

            Text(pt.prayer.displayName)
                .font(compact ? .niyaCaption : .niyaBody)
                .fontWeight(isNext(pt) ? .semibold : .regular)
                .foregroundStyle(isNext(pt) ? Color.niyaTeal : hasPassed(pt) ? Color.niyaSecondary : Color.niyaText)

            Spacer()

            if hasPassed(pt) && pt.prayer.isActualPrayer {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.niyaSecondary)
            }

            Text(formattedTime(pt.time))
                .font(compact ? .niyaCaption : .niyaBody)
                .monospacedDigit()
                .foregroundStyle(isNext(pt) ? Color.niyaTeal : hasPassed(pt) ? Color.niyaSecondary : Color.niyaText)
        }
        .padding(.vertical, compact ? 2 : 4)
    }

    private var hijriDateHeader: some View {
        Group {
            let hijriCal = Calendar(identifier: .islamicUmmAlQura)
            let comps = hijriCal.dateComponents([.year, .month, .day], from: now)
            let formatter = DateFormatter()
            let _ = { formatter.calendar = hijriCal; formatter.dateFormat = "d MMMM yyyy" }()
            if let y = comps.year, let m = comps.month, let d = comps.day {
                Text(hijriDateString(year: y, month: m, day: d))
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)
            }
        }
    }

    private func hijriDateString(year: Int, month: Int, day: Int) -> String {
        let months = ["Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani",
                      "Jumada al-Ula", "Jumada al-Thani", "Rajab", "Sha'ban",
                      "Ramadan", "Shawwal", "Dhul Qi'dah", "Dhul Hijjah"]
        let monthName = (month >= 1 && month <= 12) ? months[month - 1] : "Unknown"
        return "\(day) \(monthName) \(year) AH"
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
