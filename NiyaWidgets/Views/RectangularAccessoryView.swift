import SwiftUI
import WidgetKit

struct RectangularAccessoryView: View {
    let entry: PrayerTimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = entry.nextPrayer {
                HStack {
                    Image(systemName: next.icon)
                        .font(.caption)
                    Text(next.name)
                        .font(.system(.caption, design: .serif, weight: .semibold))
                    Spacer()
                    Text(next.time, style: .relative)
                        .font(.system(.caption2, design: .serif))
                }

                HStack(spacing: 0) {
                    Text(verbatim: HijriFormatter.format(date: entry.date, includeYear: true))
                    Text(verbatim: " \u{2022} ")
                    Text(verbatim: formattedTime(next.time))
                }
                .font(.system(.caption2, design: .serif))
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
