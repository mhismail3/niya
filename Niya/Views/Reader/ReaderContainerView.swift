import SwiftUI

struct ReaderContainerView: View {
    @State var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var storedScript: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true

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
                modeToggle
            }
            ToolbarItem(placement: .topBarLeading) {
                if vm.mode == .page {
                    Text(vm.pageLabel)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                }
            }
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
        .safeAreaInset(edge: .bottom) {
            downloadButton
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    private var modeToggle: some View {
        Picker("Mode", selection: $vm.mode) {
            ForEach(ReaderMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
    }

    @ViewBuilder
    private var downloadButton: some View {
        let isDownloaded = audioPlayerVM.isDownloaded(vm.surah.id)
        let isDownloading = audioPlayerVM.downloadingSurahId == vm.surah.id

        if !isDownloaded {
            Button {
                Task { await audioPlayerVM.downloadSurah(vm.surah.id) }
            } label: {
                HStack {
                    if isDownloading {
                        ProgressView(value: audioPlayerVM.downloadProgress)
                            .tint(Color.niyaGold)
                            .frame(width: 80)
                        Text("Downloading…")
                            .font(.subheadline)
                    } else {
                        Image(systemName: "arrow.down.circle")
                        Text("Download Audio")
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(Color.niyaTeal)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.niyaTeal.opacity(0.1))
                .clipShape(Capsule())
            }
            .disabled(isDownloading)
        }
    }
}
