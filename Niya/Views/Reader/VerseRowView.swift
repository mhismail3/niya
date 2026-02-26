import SwiftUI

struct VerseRowView: View {
    let verse: Verse
    let script: QuranScript
    let showTranslation: Bool
    let isPlaying: Bool
    let isBookmarked: Bool
    let onPlay: () -> Void
    let onBookmark: () -> Void
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .top) {
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                        .font(.title3)
                        .foregroundStyle(isPlaying ? Color.niyaGold : Color.niyaSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onBookmark) {
                    Image(systemName: isBookmarked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(isBookmarked ? .red : Color.niyaSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                verseNumberBadge
            }

            Text(verse.text)
                .font(.quranText(script: script, size: arabicFontSize))
                .foregroundStyle(Color.niyaText)
                .multilineTextAlignment(.trailing)
                .lineSpacing(12)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if showTranslation, !verse.translation.isEmpty {
                Text(verse.translation)
                    .font(.system(size: translationFontSize, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background {
            if isPlaying {
                Color.niyaGold.opacity(0.06)
                    .padding(.horizontal, -16)
            }
        }
    }

    private var verseNumberBadge: some View {
        ZStack {
            Image(systemName: "diamond")
                .font(.system(size: 32))
                .foregroundStyle(Color.niyaTeal.opacity(0.15))
            Text("\(verse.id)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
        }
    }
}
