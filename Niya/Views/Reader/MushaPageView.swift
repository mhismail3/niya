import SwiftUI

struct MushaPageView: View {
    let verses: [Verse]
    let script: QuranScript
    let showTranslation: Bool
    let surahId: Int
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM

    let showBismillah: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if showBismillah, verses.first?.id == 1 {
                    bismillahHeader
                }
                ForEach(verses) { verse in
                    VerseRowView(
                        verse: verse,
                        script: script,
                        showTranslation: showTranslation,
                        isPlaying: audioPlayerVM.isPlayingVerse(surahId: surahId, ayahId: verse.id),
                        onPlay: { audioPlayerVM.playVerse(surahId: surahId, ayahId: verse.id) }
                    )
                    Divider()
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var bismillahHeader: some View {
        Text("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ")
            .font(.custom(QuranScript.hafs.fontName, size: 26))
            .foregroundStyle(Color.niyaGold)
            .frame(maxWidth: .infinity, alignment: .center)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.vertical, 20)
    }
}
