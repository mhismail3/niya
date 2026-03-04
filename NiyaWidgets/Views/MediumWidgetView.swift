import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: PrayerTimeEntry

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(entry.data.hijriDate)
                Spacer()
                Text(entry.data.locationName)
            }
            .font(.system(.caption2, design: .serif))
            .foregroundStyle(Color.niyaSecondary)
            .lineLimit(1)

            PrayerProgressBar(progress: entry.dayProgress)
                .padding(.top, 6)

            Spacer()

            if let next = entry.nextPrayer {
                HStack(spacing: 4) {
                    Text(next.time, style: .relative)
                    Spacer()
                    Text("until \(next.name)")
                }
                .font(.system(.headline, design: .serif, weight: .medium))
                .foregroundStyle(Color.niyaTeal)
                .lineLimit(1)
            }

            if entry.isFallback {
                Text("Open Niya to configure")
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(entry.data.prayers, id: \.name) { prayer in
                    VStack(spacing: 2) {
                        Text(prayer.name)
                            .font(.system(.caption2, design: .serif))
                        Text(formattedTime(prayer.time))
                            .font(.system(.caption, design: .serif))
                            .monospacedDigit()
                    }
                    .foregroundStyle(prayerColor(prayer))
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func prayerColor(_ prayer: WidgetPrayer) -> Color {
        switch entry.prayerState(prayer) {
        case .current: return .niyaGold
        case .next: return .niyaTeal
        case .passed: return .niyaSecondary
        case .future: return .niyaText
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        f.timeZone = TimeZone(identifier: entry.data.timezoneIdentifier) ?? .current
        return f.string(from: date)
    }
}
