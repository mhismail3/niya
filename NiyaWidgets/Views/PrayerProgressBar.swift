import SwiftUI
import WidgetKit

struct PrayerProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.niyaSecondary.opacity(0.3))

                Capsule()
                    .fill(Color.niyaGold)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 4)
    }
}
