import SwiftUI

struct ReaderSettingsSheet: View {
    @Bindable var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @AppStorage(StorageKey.selectedScript) private var script: QuranScript = .hafs
    @AppStorage(StorageKey.showTranslation) private var showTranslation: Bool = true
    @AppStorage(StorageKey.showTajweed) private var showTajweed: Bool = true
    @AppStorage(StorageKey.followAlong) private var followAlong: Bool = false
    @AppStorage(StorageKey.followAlongTransliteration) private var followAlongTransliteration: Bool = true
    @AppStorage(StorageKey.followAlongMeaning) private var followAlongMeaning: Bool = true
    @AppStorage(StorageKey.followAlongAutoAdvance) private var followAlongAutoAdvance: Bool = true
    @AppStorage(StorageKey.followAlongLoopCount) private var followAlongLoopCount: Int = 1
    @AppStorage(StorageKey.arabicFontSize) private var arabicFontSize: Double = 28
    @AppStorage(StorageKey.translationFontSize) private var translationFontSize: Double = 16
    @AppStorage(StorageKey.hadithArabicFontSize) private var hadithArabicFontSize: Double = 22
    @AppStorage(StorageKey.appearanceMode) private var appearanceMode: Int = 0
    @AppStorage(StorageKey.selectedReciter) private var selectedReciter: Reciter = .alAfasy
    @AppStorage(StorageKey.prayerNotificationsEnabled) private var prayerNotifications: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ReadingSettingsSection(mode: $vm.mode, script: $script, showTranslation: $showTranslation, showTajweed: $showTajweed)
                WordByWordSettingsSection(followAlong: $followAlong, followAlongTransliteration: $followAlongTransliteration, followAlongMeaning: $followAlongMeaning, script: script)
                FontSizeSettingsSection(arabicFontSize: $arabicFontSize, translationFontSize: $translationFontSize)
                HadithFontSizeSection(hadithArabicFontSize: $hadithArabicFontSize)
                AppearanceSettingsSection(appearanceMode: $appearanceMode)
                AudioSettingsSection(selectedReciter: $selectedReciter, autoAdvance: $followAlongAutoAdvance, loopCount: $followAlongLoopCount) {
                    downloadRow
                }
                PrayerTimesSettingsSection(prayerNotifications: $prayerNotifications)
                DedicationFooter()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .hiddenNavBarBackground()
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
