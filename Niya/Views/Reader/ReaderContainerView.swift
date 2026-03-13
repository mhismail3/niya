import SwiftUI
import TipKit

struct ReaderContainerView: View {
    @State var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
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
    @AppStorage(StorageKey.showJuzProgress) private var showJuzProgress: Bool = true
    @State private var showSettings = false
    @State private var showBookmarks = false
    @State private var showGoToAyah = false
    @State private var goToAyahText = ""
    @State private var showTajweedGuide = false
    @State private var positionSaveTask: Task<Void, Never>?

    private let bookmarkToolbarTip = BookmarkToolbarTip()
    private let optionsMenuTip = OptionsMenuTip()
    private let settingsToolbarTip = SettingsToolbarTip()
    private let playVerseTip = PlayVerseTip()
    private let bookmarkVerseTip = BookmarkVerseTip()

    var body: some View {
        Group {
            switch vm.mode {
            case .scroll:
                ScrollReaderView(vm: vm)
            case .page:
                PageReaderView(vm: vm)
            }
        }
        .environment(\.highlightedAyahId, vm.highlightedAyahId)
        .environment(\.showTajweedGuide) { showTajweedGuide = true }
        .overlay(alignment: .topTrailing) {
            if showJuzProgress {
                JuzProgressAccessory(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
                    .padding(.trailing, 16)
                    .padding(.top, 4)
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
                                audioPlayerVM.stop()
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
                        goToAyahText = ""
                        showGoToAyah = true
                    } label: {
                        Label("Go to Ayah", systemImage: "arrow.forward.to.line")
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
                    if showTajweed && storedScript == .hafs {
                        Button { showTajweedGuide = true } label: {
                            Label("Tajweed Guide", systemImage: "paintpalette")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .popoverTip(optionsMenuTip)
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
            SettingsView(readerVM: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showTajweedGuide) {
            TajweedGuideView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .alert("Go to Ayah", isPresented: $showGoToAyah) {
            TextField("1–\(vm.surah.totalVerses)", text: $goToAyahText)
                .keyboardType(.numberPad)
            Button("Go") {
                if let num = Int(goToAyahText), num >= 1, num <= vm.surah.totalVerses {
                    autoScrollVM.stop()
                    vm.goToAyah(num)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(Color.niyaBackground)
        .onAppear {
            coordinator.isReaderVisible = true
            coordinator.updateReadingPosition(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
            vm.mode = storedMode
            vm.load()
            audioPlayerVM.autoAdvance = followAlongAutoAdvance
            audioPlayerVM.loopCount = followAlongLoopCount
            if followAlong && storedScript == .hafs {
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
        .onChange(of: followAlongAutoAdvance) { _, on in
            followAlongVM.autoAdvance = on
            audioPlayerVM.autoAdvance = on
        }
        .onChange(of: followAlongLoopCount) { _, count in
            followAlongVM.setLoopCount(count)
            audioPlayerVM.loopCount = count
        }
        .onChange(of: selectedReciter) { _, newReciter in
            followAlongVM.stopTracking()
            if followAlong && storedScript == .hafs {
                Task { await wordDataService.load(reciter: newReciter) }
            }
        }
        .onChange(of: selectedTranslationIds) { _, _ in
            vm.reloadTranslation()
        }
        .onChange(of: vm.visibleAyahId) { _, newAyah in
            coordinator.updateReadingPosition(surahId: vm.surah.id, ayahId: newAyah)
            guard vm.hasUserScrolled else { return }
            positionSaveTask?.cancel()
            positionSaveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                stores.readingPosition.save(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
            }
        }
        .onDisappear {
            coordinator.isReaderVisible = false
            coordinator.clearReadingPosition()
            followAlongVM.pauseTracking()
            autoScrollVM.stop()
            positionSaveTask?.cancel()
            guard vm.hasUserScrolled else { return }
            stores.readingPosition.save(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
        }
        .task { await monitorTipChain() }
    }

    private func monitorTipChain() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await Self.awaitInvalidation(bookmarkToolbarTip) { OptionsMenuTip.bookmarkDismissed = true } }
            group.addTask { await Self.awaitInvalidation(optionsMenuTip) { SettingsToolbarTip.optionsMenuDismissed = true } }
            group.addTask { await Self.awaitInvalidation(settingsToolbarTip) { PlayVerseTip.settingsDismissed = true } }
            group.addTask { await Self.awaitInvalidation(playVerseTip) { BookmarkVerseTip.playDismissed = true } }
            group.addTask { await Self.awaitInvalidation(bookmarkVerseTip) { TafsirVerseTip.bookmarkVerseDismissed = true } }
        }
    }

    @Sendable
    private static func awaitInvalidation(_ tip: some Tip, then action: @Sendable () -> Void) async {
        for await status in tip.statusUpdates {
            if case .invalidated = status {
                action()
                break
            }
        }
    }
}
