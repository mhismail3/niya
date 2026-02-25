import SwiftUI

struct ReaderSettingsSheet: View {
    @Bindable var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true

    var body: some View {
        NavigationStack {
            List {
                Section("Reading Mode") {
                    Picker("Mode", selection: $vm.mode) {
                        ForEach(ReaderMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Reading") {
                    Picker("Script", selection: $script) {
                        ForEach(QuranScript.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    Toggle("Show Translation", isOn: $showTranslation)
                        .tint(Color.niyaTeal)
                }

                Section("Audio") {
                    LabeledContent("Reciter", value: "Mishary Rashid Al-Afasy")
                    downloadRow
                }

                Section("About") {
                    LabeledContent("Quran Text", value: "quran-json (MIT)")
                    LabeledContent("Simple Arabic", value: "alquran.cloud (CC-BY)")
                    LabeledContent("Font", value: "Scheherazade New (OFL)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var downloadRow: some View {
        let isDownloaded = audioPlayerVM.isDownloaded(vm.surah.id)
        let isDownloading = audioPlayerVM.downloadingSurahId == vm.surah.id

        if isDownloaded {
            Label("Audio Downloaded", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.niyaTeal)
        } else {
            Button {
                Task { await audioPlayerVM.downloadSurah(vm.surah.id) }
            } label: {
                HStack {
                    Label("Download Audio", systemImage: "arrow.down.circle")
                    Spacer()
                    if isDownloading {
                        ProgressView(value: audioPlayerVM.downloadProgress)
                            .frame(width: 60)
                            .tint(Color.niyaGold)
                    }
                }
            }
            .disabled(isDownloading)
        }
    }
}
