import SwiftUI
import SwiftData

struct MushaPageView: View {
    let verses: [Verse]
    let script: QuranScript
    let surahId: Int
    let surahName: String
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(\.stores) private var stores
    @Query private var bookmarks: [QuranBookmark]
    @State private var tafsirAyahId: IdentifiableInt?

    let showBismillah: Bool

    init(verses: [Verse], script: QuranScript, surahId: Int, surahName: String, showBismillah: Bool) {
        self.verses = verses
        self.script = script
        self.surahId = surahId
        self.surahName = surahName
        self.showBismillah = showBismillah
        _bookmarks = Query(filter: #Predicate<QuranBookmark> { $0.surahId == surahId })
    }

    private var bookmarkedAyahSet: Set<Int> {
        Set(bookmarks.map(\.ayahId))
    }

    private var bookmarkColors: [Int: BookmarkColor] {
        var colors: [Int: BookmarkColor] = [:]
        for b in bookmarks {
            if let c = b.bookmarkColor { colors[b.ayahId] = c }
        }
        return colors
    }

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
                        isBookmarked: bookmarkedAyahSet.contains(verse.id),
                        bookmarkColor: bookmarkColors[verse.id],
                        isFirstVerse: verse.id == 1,
                        onPlay: {
                            if audioPlayerVM.isPlayingVerse(surahId: surahId, ayahId: verse.id) {
                                audioPlayerVM.togglePause()
                            } else {
                                audioPlayerVM.playVerse(surahId: surahId, ayahId: verse.id)
                            }
                        },
                        onBookmark: { toggleBookmark(verse.id) },
                        onSetBookmarkColor: { color in setBookmarkColor(verse.id, color: color) },
                        onTafsir: { tafsirAyahId = IdentifiableInt(verse.id) }
                    )
                    Divider()
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .environment(\.layoutDirection, .leftToRight)
        .sheet(item: $tafsirAyahId) { item in
            TafsirSheetView(surahId: surahId, ayahId: item.value, surahName: surahName)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private func toggleBookmark(_ ayahId: Int) {
        stores.quranBookmarks.toggle(surahId: surahId, ayahId: ayahId)
    }

    private func setBookmarkColor(_ ayahId: Int, color: BookmarkColor?) {
        stores.quranBookmarks.setColor(color, surahId: surahId, ayahId: ayahId)
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
