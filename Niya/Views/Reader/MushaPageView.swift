import SwiftUI

struct MushaPageView: View {
    let verses: [Verse]
    let script: QuranScript
    let showTranslation: Bool
    let surahId: Int
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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
        .background(Color.niyaBackground)
    }
}
