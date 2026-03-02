import SwiftUI

struct ScrollReaderView: View {
    let vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(AutoScrollViewModel.self) private var autoScrollVM
    @Environment(\.stores) private var stores
    @State private var bookmarkedAyahs: Set<Int> = []
    @State private var showTafsir = false
    @State private var tafsirAyahId: Int = 1
    @State private var uiScrollView: UIScrollView?
    @State private var scrollTask: Task<Void, Never>?

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
                            isFirstVerse: verse.id == 1,
                            onPlay: { audioPlayerVM.playVerse(surahId: vm.surah.id, ayahId: verse.id) },
                            onBookmark: { toggleBookmark(verse.id) },
                            onTafsir: { tafsirAyahId = verse.id; showTafsir = true }
                        )
                        .id(verse.id)
                        .onAppear { vm.updateVisibleAyah(verse.id) }
                        Divider()
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
                .background(ScrollViewFinder(scrollView: $uiScrollView))
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
            .onChange(of: audioPlayerVM.currentVerseID) { _, vid in
                guard let vid, vid.surahId == vm.surah.id else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(vid.ayahId, anchor: .top)
                }
            }
            .onChange(of: followAlongVM.currentVerseId) { _, ayahId in
                guard let ayahId, followAlongVM.currentSurahId == vm.surah.id else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(ayahId, anchor: .top)
                }
            }
        }
        .background(Color.niyaBackground)
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkChanged)) { _ in
            loadBookmarks()
        }
        .sheet(isPresented: $showTafsir) {
            TafsirSheetView(surahId: vm.surah.id, ayahId: tafsirAyahId, surahName: vm.surah.transliteration)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: autoScrollVM.isScrolling) { _, scrolling in
            if scrolling {
                startAutoScroll()
            } else {
                scrollTask?.cancel()
                scrollTask = nil
            }
        }
        .onChange(of: autoScrollVM.isEnabled) { _, enabled in
            if !enabled {
                scrollTask?.cancel()
                scrollTask = nil
            }
        }
        .onDisappear {
            scrollTask?.cancel()
            scrollTask = nil
        }
    }

    // MARK: - Auto Scroll (direct UIScrollView access)

    private func startAutoScroll() {
        guard let sv = uiScrollView else { return }
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            while !Task.isCancelled && autoScrollVM.isScrolling && autoScrollVM.isEnabled {
                let speed = autoScrollVM.pointsPerSecond
                let currentY = sv.contentOffset.y
                let newY = currentY + speed / 30.0
                let maxY = sv.contentSize.height - sv.bounds.height

                if maxY > 0 && newY >= maxY {
                    sv.contentOffset.y = maxY
                    autoScrollVM.isScrolling = false
                    return
                }

                sv.contentOffset.y = newY

                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    // MARK: - Bookmarks

    private func loadBookmarks() {
        let all = stores!.quranBookmarks.allBookmarks().filter { $0.surahId == vm.surah.id }
        bookmarkedAyahs = Set(all.map(\.ayahId))
    }

    private func toggleBookmark(_ ayahId: Int) {
        stores!.quranBookmarks.toggle(surahId: vm.surah.id, ayahId: ayahId)
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

// MARK: - UIScrollView Finder

private struct ScrollViewFinder: UIViewRepresentable {
    @Binding var scrollView: UIScrollView?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if scrollView == nil {
                scrollView = uiView.findEnclosingScrollView()
            }
        }
    }
}

private extension UIView {
    func findEnclosingScrollView() -> UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let sv = view as? UIScrollView {
                return sv
            }
            current = view.superview
        }
        return nil
    }
}
