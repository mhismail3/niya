import SwiftUI

struct VerseNumberBadge: View {
    let verseId: Int
    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 24

    var body: some View {
        ZStack {
            Image(systemName: "diamond")
                .font(.system(size: badgeSize))
                .foregroundStyle(Color.niyaTeal.opacity(0.15))
            Text("\(verseId)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
        }
        .accessibilityLabel("Verse \(verseId)")
    }
}
