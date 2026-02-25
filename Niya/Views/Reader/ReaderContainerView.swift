import SwiftUI

struct ReaderContainerView: View {
    @State var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var storedScript: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var showSettings = false

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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if vm.mode == .page {
                    Text(vm.pageLabel)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color.niyaBackground)
        }
        .background(Color.niyaBackground)
        .onAppear {
            vm.load()
        }
        .onChange(of: storedScript) { _, newScript in
            vm.reloadForScript(newScript)
        }
        .onChange(of: showTranslation) { _, show in
            vm.showTranslation = show
        }
        .onDisappear {
            ReadingPositionStore(modelContext: modelContext)
                .save(surahId: vm.surah.id, ayahId: vm.visibleAyahId)
        }
    }
}
