import SwiftUI
import WidgetKit

struct RectangularAccessoryView: View {
    let entry: PrayerTimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = entry.nextPrayer {
                HStack(spacing: 4) {
                    Text("\(next.name) at \(formattedTime(next.time))")
                        .font(.system(.caption, design: .serif, weight: .semibold))
                }

                (Text(next.time, style: .relative) + Text(" left"))
                    .font(.system(size: 10.5, design: .serif))
                    .foregroundStyle(.secondary)

                Text(verbatim: HijriFormatter.format(date: entry.date, includeYear: true))
                    .font(.system(size: 10.5, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(verbatim: HijriFormatter.format(date: entry.date, includeYear: true))
                    .font(.system(size: 10.5, design: .serif))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone = TimeZone(identifier: entry.data.timezoneIdentifier) ?? .current
        return f.string(from: date)
    }
}
