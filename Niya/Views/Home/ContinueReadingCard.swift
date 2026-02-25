import SwiftUI

struct ContinueReadingCard: View {
    let surah: Surah
    let position: ReadingPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(surah.name)
                .font(.custom(QuranScript.hafs.fontName, size: 22))
                .foregroundStyle(Color.niyaGold)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(surah.transliteration)
                .font(.headline)
                .foregroundStyle(Color.niyaText)

            Text("Verse \(position.lastAyahId) of \(surah.totalVerses)")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)

            ProgressView(value: progress)
                .tint(Color.niyaTeal)

            Text(position.lastReadAt.relativeFormatted)
                .font(.caption2)
                .foregroundStyle(Color.niyaSecondary)
        }
        .padding(12)
        .frame(width: 200)
        .niyaCard()
    }

    var progress: Double {
        guard surah.totalVerses > 0 else { return 0 }
        return min(max(Double(position.lastAyahId) / Double(surah.totalVerses), 0), 1)
    }
}
