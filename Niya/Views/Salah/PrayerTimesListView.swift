import SwiftUI

struct PrayerTimesListView: View {
    let times: DailyPrayerTimes
    let timeZone: TimeZone
    var locationName: String = ""
    var showAll: Bool = true
    var compact: Bool = false

    private var now: Date { Date() }

    private var currentPrayer: PrayerName? {
        let actual = times.times.filter { $0.prayer.isActualPrayer }
        for (i, pt) in actual.enumerated() {
            let nextTime = i + 1 < actual.count ? actual[i + 1].time : nil
            if pt.time <= now && (nextTime == nil || now < nextTime!) {
                return pt.prayer
            }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            if showAll {
                dateLocationHeader
            }

            ForEach(displayTimes, id: \.prayer) { pt in
                if showAll || isCurrent(pt) || isUpcoming(pt) || isNext(pt) {
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
        guard let nextPrayer = next else {
            return times.times.filter { $0.prayer.isActualPrayer }
        }
        let nextIdx = times.times.firstIndex(where: { $0.prayer == nextPrayer.prayer }) ?? 0
        if let cur = currentPrayer,
           let curIdx = times.times.firstIndex(where: { $0.prayer == cur }),
           curIdx < nextIdx {
            return Array(times.times[curIdx...])
        }
        return Array(times.times[nextIdx...])
    }

    private func isNext(_ pt: PrayerTime) -> Bool {
        times.nextPrayer(after: now)?.prayer == pt.prayer
    }

    private func isUpcoming(_ pt: PrayerTime) -> Bool {
        pt.time > now
    }

    private func isCurrent(_ pt: PrayerTime) -> Bool {
        pt.prayer == currentPrayer
    }

    private func hasPassed(_ pt: PrayerTime) -> Bool {
        pt.time <= now && !isCurrent(pt)
    }

    private func rowColor(_ pt: PrayerTime) -> Color {
        if isCurrent(pt) { return Color.niyaGold }
        if isNext(pt) { return Color.niyaTeal }
        if hasPassed(pt) { return Color.niyaSecondary }
        return Color.niyaText
    }

    private func prayerRow(_ pt: PrayerTime) -> some View {
        HStack {
            Image(systemName: pt.prayer.icon)
                .frame(width: 24)
                .foregroundStyle(rowColor(pt))

            Text(pt.prayer.displayName)
                .font(compact ? .niyaCaption : .niyaBody)
                .fontWeight(isCurrent(pt) || isNext(pt) ? .semibold : .regular)
                .foregroundStyle(rowColor(pt))

            Spacer()

            if hasPassed(pt) && pt.prayer.isActualPrayer {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.niyaSecondary)
            } else if isCurrent(pt) {
                Text("Now")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.niyaGold)
            }

            Text(formattedTime(pt.time))
                .font(compact ? .niyaCaption : .niyaBody)
                .monospacedDigit()
                .foregroundStyle(rowColor(pt))
        }
        .padding(.vertical, compact ? 2 : 4)
    }

    private var dateLocationHeader: some View {
        Group {
            let hijriCal = Calendar(identifier: .islamicUmmAlQura)
            let comps = hijriCal.dateComponents([.year, .month, .day], from: now)
            if let y = comps.year, let m = comps.month, let d = comps.day {
                HStack {
                    Text(hijriDateString(year: y, month: m, day: d))
                    if !locationName.isEmpty {
                        Spacer()
                        Text(locationName)
                    }
                }
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
