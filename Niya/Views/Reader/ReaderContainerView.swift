import SwiftUI
import TipKit

struct ReaderContainerView: View {
    @State var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(TajweedService.self) private var tajweedService
    @Environment(WordDataService.self) private var wordDataService
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var storedScript: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("showTajweed") private var showTajweed: Bool = true
    @AppStorage("followAlong") private var followAlong: Bool = false
    @AppStorage("followAlongAutoAdvance") private var followAlongAutoAdvance: Bool = true
    @AppStorage("followAlongLoopCount") private var followAlongLoopCount: Int = 1
    @AppStorage("readerMode") private var storedMode: ReaderMode = .scroll
    @AppStorage("selectedReciter") private var selectedReciter: Reciter = .alAfasy
    @AppStorage("selectedTranslation") private var selectedTranslationId: String = "en_sahih"
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
            if audioPlayerVM.hasActiveSession {
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
                if storedScript == .hafs {
                    Button {
                        followAlong.toggle()
                        if followAlong {
                            Task { await wordDataService.load(reciter: selectedReciter) }
                        } else {
                            followAlongVM.stopTracking()
                        }
                    } label: {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(followAlong ? Color.niyaGold : Color.niyaSecondary)
                    }
                    .popoverTip(followAlongToolbarTip)
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
                .presentationDragIndicator(.visible)
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
        .onChange(of: showTranslation) { _, show in
            vm.showTranslation = show
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
        .onChange(of: selectedTranslationId) { _, _ in
            vm.reloadTranslation()
        }
        .onDisappear {
            coordinator.isReaderVisible = false
            followAlongVM.pauseTracking()
            guard vm.hasUserScrolled else { return }
            ReadingPositionStore(modelContext: modelContext)
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
