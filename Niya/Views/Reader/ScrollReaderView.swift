import SwiftUI

struct ScrollReaderView: View {
    let vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(\.modelContext) private var modelContext
    @State private var bookmarkedAyahs: Set<Int> = []

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if vm.showBismillah {
                        bismillahHeader
                    }
                    ForEach(vm.verses) { verse in
                        VerseCellView(
                            verse: verse,
                            surahId: vm.surah.id,
                            script: vm.script,
                            showTranslation: vm.showTranslation,
                            isPlaying: audioPlayerVM.isPlayingVerse(surahId: vm.surah.id, ayahId: verse.id),
                            isBookmarked: bookmarkedAyahs.contains(verse.id),
                            onPlay: { audioPlayerVM.playVerse(surahId: vm.surah.id, ayahId: verse.id) },
                            onBookmark: { toggleBookmark(verse.id) }
                        )
                        .id(verse.id)
                        .onAppear { vm.updateVisibleAyah(verse.id) }
                        Divider()
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .onAppear {
                loadBookmarks()
                if let target = vm.initialAyahId, target > 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    vm.isSettled = true
                }
            }
        }
        .background(Color.niyaBackground)
    }

    private func loadBookmarks() {
        let store = QuranBookmarkStore(modelContext: modelContext)
        let all = store.allBookmarks().filter { $0.surahId == vm.surah.id }
        bookmarkedAyahs = Set(all.map(\.ayahId))
    }

    private func toggleBookmark(_ ayahId: Int) {
        let store = QuranBookmarkStore(modelContext: modelContext)
        store.toggle(surahId: vm.surah.id, ayahId: ayahId)
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
