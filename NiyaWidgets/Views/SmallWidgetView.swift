import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: PrayerTimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = entry.nextPrayer {
                HStack(spacing: 4) {
                    Image(systemName: next.icon)
                        .font(.caption)
                    Text(next.name)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                }
                .foregroundStyle(Color.niyaGold)

                Spacer()

                Text(next.time, style: .relative)
                    .font(.system(.subheadline, design: .serif, weight: .medium))
                    .foregroundStyle(Color.niyaTeal)
                    .lineLimit(1)

                Spacer()

                Text(formattedTime(next.time))
                    .font(.system(.caption, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Color.niyaText)

                Text(HijriFormatter.format(date: entry.date, includeYear: false))
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)

                if entry.isFallback {
                    Text("Open Niya to set up")
                        .font(.system(.caption2, design: .serif))
                        .foregroundStyle(Color.niyaSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone = TimeZone(identifier: entry.data.timezoneIdentifier) ?? .current
        return f.string(from: date)
    }
}
