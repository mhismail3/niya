import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: PrayerTimeEntry

    var body: some View {
        if let next = entry.nextPrayer {
            VStack(alignment: .leading, spacing: 0) {
                Text(HijriFormatter.format(date: entry.date, includeYear: true))
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)

                Spacer()

                Text(next.time, style: .relative)
                    .font(.system(.title3, design: .serif, weight: .medium))
                    .foregroundStyle(Color.niyaTeal)
                    .lineLimit(1)

                Text("until \(next.name)")
                    .font(.system(.headline, design: .serif, weight: .medium))
                    .foregroundStyle(Color.niyaTeal)

                Spacer()

                upcomingPrayers(after: next)

                Text(entry.data.locationName)
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(HijriFormatter.format(date: entry.date, includeYear: true))
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
                Spacer()
                Text(entry.data.locationName)
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func upcomingPrayers(after current: WidgetPrayer) -> some View {
        var upcoming = entry.data.prayers.filter { $0.time > current.time }
        if upcoming.count < 2 {
            let tomorrowUpcoming = entry.data.tomorrowPrayers.filter { $0.time > current.time }
            upcoming.append(contentsOf: tomorrowUpcoming)
        }
        let display = Array(upcoming.prefix(2))
        return HStack(spacing: 0) {
            ForEach(display, id: \.name) { prayer in
                VStack(alignment: .leading, spacing: 1) {
                    Text(prayer.name)
                        .font(.system(.caption2, design: .serif))
                    Text(formattedTime(prayer.time))
                        .font(.system(.caption, design: .serif))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.niyaText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, 6)
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        f.timeZone = TimeZone(identifier: entry.data.timezoneIdentifier) ?? .current
        return f.string(from: date)
    }
}
