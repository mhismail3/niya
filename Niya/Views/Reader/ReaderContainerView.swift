import SwiftUI

struct ReaderContainerView: View {
    @State var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(TajweedService.self) private var tajweedService
    @Environment(WordDataService.self) private var wordDataService
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var storedScript: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("showTajweed") private var showTajweed: Bool = false
    @AppStorage("followAlong") private var followAlong: Bool = false
    @AppStorage("followAlongAutoAdvance") private var followAlongAutoAdvance: Bool = true
    @AppStorage("followAlongLoopCount") private var followAlongLoopCount: Int = 1
    @AppStorage("readerMode") private var storedMode: ReaderMode = .scroll
    @State private var showSettings = false
    @State private var showBookmarks = false

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
            if followAlong && followAlongVM.currentVerseId != nil {
                FollowAlongControlsView()
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.smooth, value: followAlongVM.currentVerseId != nil)
        .navigationTitle(vm.surah.transliteration)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showBookmarks = true } label: {
                    Image(systemName: "bookmark")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if storedScript == .hafs {
                    Button {
                        followAlong.toggle()
                        if followAlong {
                            Task { await wordDataService.load() }
                        } else {
                            followAlongVM.stopTracking()
                        }
                    } label: {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(followAlong ? Color.niyaGold : Color.niyaSecondary)
                    }
                }
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .bottomBar)
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
            vm.mode = storedMode
            vm.load()
            if showTajweed && storedScript == .hafs {
                tajweedService.fetch(surahId: vm.surah.id)
            }
            if followAlong && storedScript == .hafs {
                Task { await wordDataService.load() }
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
        }
        .onChange(of: followAlongLoopCount) { _, count in
            followAlongVM.loopCount = count
        }
        .onDisappear {
            followAlongVM.stopTracking()
            guard vm.hasUserScrolled else { return }
            ReadingPositionStore(modelContext: modelContext)
                .save(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
        }
    }
}
