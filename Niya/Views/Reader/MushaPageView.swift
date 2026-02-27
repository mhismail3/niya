import SwiftUI

struct MushaPageView: View {
    let verses: [Verse]
    let script: QuranScript
    let showTranslation: Bool
    let surahId: Int
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(\.modelContext) private var modelContext
    @State private var bookmarkedAyahs: Set<Int> = []

    let showBismillah: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if showBismillah, verses.first?.id == 1 {
                    bismillahHeader
                }
                ForEach(verses) { verse in
                    VerseCellView(
                        verse: verse,
                        surahId: surahId,
                        script: script,
                        showTranslation: showTranslation,
                        isPlaying: audioPlayerVM.isPlayingVerse(surahId: surahId, ayahId: verse.id),
                        isBookmarked: bookmarkedAyahs.contains(verse.id),
                        onPlay: { audioPlayerVM.playVerse(surahId: surahId, ayahId: verse.id) },
                        onBookmark: { toggleBookmark(verse.id) }
                    )
                    Divider()
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear { loadBookmarks() }
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkChanged)) { _ in
            loadBookmarks()
        }
    }

    private func loadBookmarks() {
        let store = QuranBookmarkStore(modelContext: modelContext)
        let all = store.allBookmarks().filter { $0.surahId == surahId }
        bookmarkedAyahs = Set(all.map(\.ayahId))
    }

    private func toggleBookmark(_ ayahId: Int) {
        let store = QuranBookmarkStore(modelContext: modelContext)
        store.toggle(surahId: surahId, ayahId: ayahId)
        if bookmarkedAyahs.contains(ayahId) {
            bookmarkedAyahs.remove(ayahId)
        } else {
            bookmarkedAyahs.insert(ayahId)
        }
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
