import SwiftUI

struct MushaPageView: View {
    let verses: [Verse]
    let script: QuranScript
    let surahId: Int
    let surahName: String
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(\.stores) private var stores
    @State private var bookmarkedAyahs: Set<Int> = []
    @State private var showTafsir = false
    @State private var tafsirAyahId: Int = 1

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
                        isPlaying: audioPlayerVM.isPlayingVerse(surahId: surahId, ayahId: verse.id),
                        isBookmarked: bookmarkedAyahs.contains(verse.id),
                        isFirstVerse: verse.id == 1,
                        onPlay: { audioPlayerVM.playVerse(surahId: surahId, ayahId: verse.id) },
                        onBookmark: { toggleBookmark(verse.id) },
                        onTafsir: { tafsirAyahId = verse.id; showTafsir = true }
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
        .sheet(isPresented: $showTafsir) {
            TafsirSheetView(surahId: surahId, ayahId: tafsirAyahId, surahName: surahName)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private func loadBookmarks() {
        let all = stores.quranBookmarks.allBookmarks().filter { $0.surahId == surahId }
        bookmarkedAyahs = Set(all.map(\.ayahId))
    }

    private func toggleBookmark(_ ayahId: Int) {
        stores.quranBookmarks.toggle(surahId: surahId, ayahId: ayahId)
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
