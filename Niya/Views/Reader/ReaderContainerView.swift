import SwiftUI
import TipKit

struct ReaderContainerView: View {
    @State var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(TajweedService.self) private var tajweedService
    @Environment(WordDataService.self) private var wordDataService
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(AutoScrollViewModel.self) private var autoScrollVM
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.stores) private var stores
    @AppStorage(StorageKey.selectedScript) private var storedScript: QuranScript = .hafs
    @AppStorage(StorageKey.showTajweed) private var showTajweed: Bool = true
    @AppStorage(StorageKey.followAlong) private var followAlong: Bool = false
    @AppStorage(StorageKey.followAlongAutoAdvance) private var followAlongAutoAdvance: Bool = true
    @AppStorage(StorageKey.followAlongLoopCount) private var followAlongLoopCount: Int = 1
    @AppStorage(StorageKey.readerMode) private var storedMode: ReaderMode = .scroll
    @AppStorage(StorageKey.selectedReciter) private var selectedReciter: Reciter = .alAfasy
    @AppStorage(StorageKey.selectedTranslations) private var selectedTranslationIds: String = "en_sahih"
    @State private var showSettings = false
    @State private var showBookmarks = false

    private let bookmarkToolbarTip = BookmarkToolbarTip()
    private let followAlongToolbarTip = FollowAlongToolbarTip()
    private let settingsToolbarTip = SettingsToolbarTip()

    var body: some View {
        Group {
            switch vm.mode {
            case .scroll:
                ScrollReaderView(vm: vm)
            case .page:
                PageReaderView(vm: vm)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if autoScrollVM.isEnabled || audioPlayerVM.hasActiveSession {
                Color.clear.frame(height: 80)
            }
        }
        .navigationTitle(vm.surah.transliteration)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showBookmarks = true } label: {
                    Image(systemName: "bookmark")
                }
                .popoverTip(bookmarkToolbarTip)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    if storedScript == .hafs {
                        Button {
                            followAlong.toggle()
                            if followAlong {
                                autoScrollVM.stop()
                                Task { await wordDataService.load(reciter: selectedReciter) }
                            } else {
                                followAlongVM.stopTracking()
                            }
                        } label: {
                            Label(
                                followAlong ? "Disable Word-by-Word" : "Word-by-Word",
                                systemImage: "text.word.spacing"
                            )
                        }
                    }
                    Button {
                        if autoScrollVM.isEnabled {
                            autoScrollVM.stop()
                        } else {
                            followAlongVM.stopTracking()
                            followAlong = false
                            audioPlayerVM.stop()
                            autoScrollVM.isEnabled = true
                            autoScrollVM.isScrolling = true
                        }
                    } label: {
                        Label(
                            autoScrollVM.isEnabled ? "Disable Auto-Scroll" : "Auto-Scroll",
                            systemImage: "scroll"
                        )
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .popoverTip(settingsToolbarTip)
            }
        }
        .hiddenAllToolbarBackgrounds()
        .sheet(isPresented: $showBookmarks) {
            BookmarksView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .background(Color.niyaBackground)
        .onAppear {
            coordinator.isReaderVisible = true
            vm.mode = storedMode
            vm.load()
            audioPlayerVM.autoAdvance = followAlongAutoAdvance
            audioPlayerVM.loopCount = followAlongLoopCount
            if showTajweed && storedScript == .hafs {
                tajweedService.fetch(surahId: vm.surah.id)
            }
            if followAlong && storedScript == .hafs || !selectedReciter.hasPerVerseAudio {
                Task { await wordDataService.load(reciter: selectedReciter) }
            }
            if followAlong && audioPlayerVM.hasActiveSession,
               followAlongVM.currentSurahId == vm.surah.id {
                followAlongVM.resumeTracking()
            }
        }
        .onChange(of: storedScript) { _, newScript in
            vm.reloadForScript(newScript)
            if newScript != .hafs && followAlong {
                followAlong = false
                followAlongVM.stopTracking()
            }
        }
        .onChange(of: vm.mode) { _, newMode in
            storedMode = newMode
        }
        .onChange(of: showTajweed) { _, on in
            if on && storedScript == .hafs {
                tajweedService.fetch(surahId: vm.surah.id)
            }
        }
        .onChange(of: followAlongAutoAdvance) { _, on in
            followAlongVM.autoAdvance = on
            audioPlayerVM.autoAdvance = on
        }
        .onChange(of: followAlongLoopCount) { _, count in
            followAlongVM.setLoopCount(count)
            audioPlayerVM.loopCount = count
        }
        .onChange(of: selectedTranslationIds) { _, _ in
            vm.reloadTranslation()
        }
        .onDisappear {
            coordinator.isReaderVisible = false
            followAlongVM.pauseTracking()
            autoScrollVM.stop()
            guard vm.hasUserScrolled else { return }
            stores!.readingPosition
                .save(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
        }
        .task {
            for await status in bookmarkToolbarTip.statusUpdates {
                if case .invalidated = status {
                    FollowAlongToolbarTip.bookmarkDismissed = true
                    if storedScript != .hafs {
                        SettingsToolbarTip.followAlongDismissed = true
                    }
                    break
                }
            }
        }
        .task {
            for await status in followAlongToolbarTip.statusUpdates {
                if case .invalidated = status {
                    SettingsToolbarTip.followAlongDismissed = true
                    break
                }
            }
        }
        .task {
            for await status in settingsToolbarTip.statusUpdates {
                if case .invalidated = status {
                    PlayVerseTip.settingsDismissed = true
                    break
                }
            }
        }
    }
}
