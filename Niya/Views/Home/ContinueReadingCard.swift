import SwiftUI

struct ContinueReadingCard: View {
    let surah: Surah
    let position: ReadingPosition
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        colorScheme == .light ? Color.niyaTeal.opacity(0.45) : Color.niyaTeal
    }

    var body: some View {
        HStack(spacing: 0) {
            accentColor
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 8) {
                Text(surah.name)
                    .font(.custom(QuranScript.hafs.fontName, size: 22))
                    .foregroundStyle(Color.niyaGold)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(surah.transliteration)
                    .font(.niyaHeadline)
                    .foregroundStyle(Color.niyaText)

                Spacer(minLength: 0)

                Text("Verse \(position.lastAyahId) of \(surah.totalVerses)")
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)

                ProgressView(value: progress)
                    .tint(accentColor)

                Text(position.lastReadAt.relativeFormatted)
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaSecondary)
            }
            .padding(12)
        }
        .frame(width: 150)
        .frame(minHeight: 170)
        .background(Color.niyaSurface)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 4,
                bottomTrailingRadius: 10, topTrailingRadius: 10
            )
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    var progress: Double {
        guard surah.totalVerses > 0 else { return 0 }
        return min(max(Double(position.lastAyahId) / Double(surah.totalVerses), 0), 1)
    }
}
