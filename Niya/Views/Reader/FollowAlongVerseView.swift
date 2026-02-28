import SwiftUI

struct FollowAlongVerseView: View {
    let verse: Verse
    let surahId: Int
    let verseData: VerseWordData
    let isBookmarked: Bool
    let onBookmark: () -> Void
    let onTafsir: () -> Void
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @AppStorage("followAlongTransliteration") private var showTransliteration = true
    @AppStorage("followAlongMeaning") private var showMeaning = true
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16
    @AppStorage("translationIsRTL") private var translationIsRTL: Bool = false

    private var isActiveVerse: Bool {
        followAlongVM.currentVerseId == verse.id && followAlongVM.currentSurahId == surahId
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .center) {
                Button {
                    if isActiveVerse {
                        followAlongVM.togglePlayPause()
                    } else {
                        followAlongVM.playVerse(surahId: surahId, ayahId: verse.id)
                    }
                } label: {
                    Image(systemName: isActiveVerse && followAlongVM.isPlaying ? "pause.circle.fill" : "play.circle")
                        .font(.title3)
                        .foregroundStyle(isActiveVerse ? Color.niyaGold : Color.niyaSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(isBookmarked ? Color.niyaGold : Color.niyaSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onTafsir) {
                    Image(systemName: "text.book.closed")
                        .font(.title3)
                        .foregroundStyle(Color.niyaSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                verseNumberBadge
            }

            FlowLayout(spacing: 6, rightToLeft: true) {
                ForEach(verseData.w) { word in
                    WordView(
                        word: word,
                        highlightState: followAlongVM.highlightState(for: word, verseId: verse.id),
                        showTransliteration: showTransliteration,
                        showMeaning: showMeaning,
                        onTap: { if !followAlongVM.isPlaying { followAlongVM.tapWord(word, verseId: verse.id) } }
                    )
                }
            }

            if !verse.translation.isEmpty {
                Text(verse.translation)
                    .font(.system(size: translationFontSize, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
                    .multilineTextAlignment(translationIsRTL ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: translationIsRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, translationIsRTL ? .rightToLeft : .leftToRight)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background {
            if isActiveVerse {
                Color.niyaGold.opacity(0.06)
                    .padding(.horizontal, -16)
            }
        }
    }

    private var verseNumberBadge: some View {
        ZStack {
            Image(systemName: "diamond")
                .font(.system(size: 24))
                .foregroundStyle(Color.niyaTeal.opacity(0.15))
            Text("\(verse.id)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
        }
    }
}
