import WidgetKit
import SwiftUI

@main
struct NiyaWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimeWidget()
        PrayerTimeLockWidget()
    }
}

struct PrayerTimeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PrayerTimeEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

struct PrayerTimeWidget: Widget {
    let kind = SharedConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerTimeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    if #available(iOSApplicationExtension 26.0, *) {
                        Color.clear.glassEffect()
                    } else {
                        Color.niyaSurface
                    }
                }
                .widgetURL(URL(string: "niya://salah"))
        }
        .configurationDisplayName("Prayer Times")
        .description("See prayer times and countdown to the next prayer.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PrayerTimeLockWidget: Widget {
    let kind = SharedConstants.lockWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            RectangularAccessoryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "niya://salah"))
        }
        .configurationDisplayName("Next Prayer")
        .description("Next prayer time on your lock screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}
