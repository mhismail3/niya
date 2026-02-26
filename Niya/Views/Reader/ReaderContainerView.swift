import SwiftUI

struct ReaderContainerView: View {
    @State var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(TajweedService.self) private var tajweedService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var storedScript: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("showTajweed") private var showTajweed: Bool = false
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
        .navigationTitle(vm.surah.transliteration)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showBookmarks = true } label: {
                    Image(systemName: "bookmark")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
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
        }
        .onChange(of: storedScript) { _, newScript in
            vm.reloadForScript(newScript)
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
        .onDisappear {
            guard vm.hasUserScrolled else { return }
            ReadingPositionStore(modelContext: modelContext)
                .save(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
        }
    }
}
