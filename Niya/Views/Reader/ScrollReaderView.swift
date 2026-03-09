import SwiftUI
import SwiftData

struct ScrollReaderView: View {
    let vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(AutoScrollViewModel.self) private var autoScrollVM
    @Environment(\.stores) private var stores
    @Query private var bookmarks: [QuranBookmark]
    @State private var tafsirAyahId: IdentifiableInt?
    @State private var etymologyWord: EtymologySheetItem?
    @State private var uiScrollView: UIScrollView?
    @State private var scrollTask: Task<Void, Never>?
    @State private var highlightTask: Task<Void, Never>?

    init(vm: ReaderViewModel) {
        self.vm = vm
        let surahId = vm.surah.id
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
                            isPlaying: audioPlayerVM.isPlayingVerse(surahId: vm.surah.id, ayahId: verse.id),
                            isBookmarked: bookmarkedAyahSet.contains(verse.id),
                            bookmarkColor: bookmarkColors[verse.id],
                            isFirstVerse: verse.id == 1,
                            onPlay: {
                                if audioPlayerVM.isPlayingVerse(surahId: vm.surah.id, ayahId: verse.id) {
                                    audioPlayerVM.togglePause()
                                } else {
                                    audioPlayerVM.playVerse(surahId: vm.surah.id, ayahId: verse.id)
                                }
                            },
                            onBookmark: { toggleBookmark(verse.id) },
                            onSetBookmarkColor: { color in setBookmarkColor(verse.id, color: color) },
                            onTafsir: { tafsirAyahId = IdentifiableInt(verse.id) },
                            onWordLongPress: { word in
                                etymologyWord = EtymologySheetItem(surahId: vm.surah.id, ayahId: verse.id, word: word)
                            }
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
                if let target = vm.initialAyahId, target > 1 {
                    Task { @MainActor in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    vm.isSettled = true
                }
            }
            .onChange(of: audioPlayerVM.currentVerseID) { _, vid in
                guard let vid, vid.surahId == vm.surah.id else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(vid.ayahId, anchor: .top)
                }
            }
            .onChange(of: vm.goToAyahTarget) { _, target in
                guard let target else { return }
                vm.goToAyahTarget = nil
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                highlightTask?.cancel()
                highlightTask = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.5)) {
                        vm.clearHighlight()
                    }
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
        .sheet(item: $tafsirAyahId) { item in
            TafsirSheetView(surahId: vm.surah.id, ayahId: item.value, surahName: vm.surah.transliteration)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $etymologyWord) { item in
            WordEtymologySheet(surahId: item.surahId, ayahId: item.ayahId, word: item.word)
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
            highlightTask?.cancel()
            highlightTask = nil
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

    private func toggleBookmark(_ ayahId: Int) {
        stores.quranBookmarks.toggle(surahId: vm.surah.id, ayahId: ayahId)
    }

    private func setBookmarkColor(_ ayahId: Int, color: BookmarkColor?) {
        stores.quranBookmarks.setColor(color, surahId: vm.surah.id, ayahId: ayahId)
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

struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
    init(_ value: Int) { self.value = value }
}

struct EtymologySheetItem: Identifiable {
    let surahId: Int
    let ayahId: Int
    let word: QuranWord
    var id: String { "\(surahId):\(ayahId):\(word.p)" }
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
