import SwiftUI

struct ReaderSettingsSheet: View {
    @Bindable var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("showTajweed") private var showTajweed: Bool = false
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

    var body: some View {
        NavigationStack {
            List {
                Section("Reading") {
                    LabeledContent("Reading Mode") {
                        Picker("Reading Mode", selection: $vm.mode) {
                            ForEach(ReaderMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    Picker("Script", selection: $script) {
                        ForEach(QuranScript.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    Toggle("Show Translation", isOn: $showTranslation)
                        .tint(Color.niyaTeal)
                    Toggle("Tajweed Colors", isOn: $showTajweed)
                        .tint(Color.niyaTeal)
                        .disabled(script != .hafs)
                    if script != .hafs {
                        Text("Available for Uthmanic Hafs only")
                            .font(.caption)
                            .foregroundStyle(Color.niyaSecondary)
                    }
                }

                Section("Font Size") {
                    LabeledContent("Arabic — \(Int(arabicFontSize))") {
                        Slider(value: $arabicFontSize, in: 20...40, step: 1)
                            .frame(width: 160)
                            .tint(Color.niyaTeal)
                    }
                    LabeledContent("Translation — \(Int(translationFontSize))") {
                        Slider(value: $translationFontSize, in: 12...24, step: 1)
                            .frame(width: 160)
                            .tint(Color.niyaTeal)
                    }
                }

                Section("Appearance") {
                    Picker("Mode", selection: $appearanceMode) {
                        Text("Auto").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Audio") {
                    LabeledContent("Reciter", value: "Mishary Rashid Al-Afasy")
                    downloadRow
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
