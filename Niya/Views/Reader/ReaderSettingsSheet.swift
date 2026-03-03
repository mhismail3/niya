import SwiftUI

struct ReaderSettingsSheet: View {
    @Bindable var vm: ReaderViewModel
    @Environment(DownloadManager.self) private var downloadManager
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
        let surahId = vm.surah.id
        let downloaded = downloadManager.isDownloaded(surahId, reciter: selectedReciter)
        let prog = downloadManager.progress(for: surahId, reciter: selectedReciter)

        if downloaded {
            HStack {
                Label("Audio Downloaded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.niyaTeal)
                Spacer()
                Button(role: .destructive) {
                    try? downloadManager.deleteSurah(surahId, reciter: selectedReciter)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        } else if let prog {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if prog.error != nil {
                        Label("Download Failed", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } else {
                        Label("Downloading…", systemImage: "arrow.down.circle")
                    }
                    Spacer()
                    Button {
                        downloadManager.cancelDownload(surahId, reciter: selectedReciter)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.niyaSecondary)
                    }
                    .buttonStyle(.plain)
                }
                if let errorMsg = prog.error {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(.red)
                    HStack(spacing: 12) {
                        Button("Retry") {
                            downloadManager.dismissError(surahId, reciter: selectedReciter)
                            downloadManager.downloadSurah(surahId, reciter: selectedReciter)
                        }
                        .font(.caption)
                        Button("Dismiss") {
                            downloadManager.dismissError(surahId, reciter: selectedReciter)
                        }
                        .font(.caption)
                        .foregroundStyle(Color.niyaSecondary)
                    }
                } else {
                    ProgressView(value: prog.progress)
                        .tint(Color.niyaGold)
                }
            }
        } else {
            Button {
                downloadManager.downloadSurah(surahId, reciter: selectedReciter)
            } label: {
                Label("Download Audio", systemImage: "arrow.down.circle")
            }
        }
    }
}
