import SwiftUI

struct SettingsView: View {
    @AppStorage(StorageKey.selectedScript) private var script: QuranScript = .hafs
    @AppStorage(StorageKey.showTranslation) private var showTranslation: Bool = true
    @AppStorage(StorageKey.showTajweed) private var showTajweed: Bool = true
    @AppStorage(StorageKey.followAlong) private var followAlong: Bool = false
    @AppStorage(StorageKey.followAlongTransliteration) private var followAlongTransliteration: Bool = true
    @AppStorage(StorageKey.followAlongMeaning) private var followAlongMeaning: Bool = true
    @AppStorage(StorageKey.followAlongAutoAdvance) private var followAlongAutoAdvance: Bool = true
    @AppStorage(StorageKey.followAlongLoopCount) private var followAlongLoopCount: Int = 1
    @AppStorage(StorageKey.readerMode) private var mode: ReaderMode = .scroll
    @AppStorage(StorageKey.arabicFontSize) private var arabicFontSize: Double = 28
    @AppStorage(StorageKey.translationFontSize) private var translationFontSize: Double = 16
    @AppStorage(StorageKey.hadithArabicFontSize) private var hadithArabicFontSize: Double = 22
    @AppStorage(StorageKey.appearanceMode) private var appearanceMode: Int = 0
    @AppStorage(StorageKey.selectedReciter) private var selectedReciter: Reciter = .alAfasy
    @AppStorage(StorageKey.showJuzProgress) private var showJuzProgress: Bool = true
    @AppStorage(StorageKey.prayerNotificationsEnabled) private var prayerNotifications: Bool = false
    @State private var showGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showGuide = true
                    } label: {
                        Label {
                            Text("How to Use This App").fontWeight(.semibold)
                        } icon: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                }
                ReadingSettingsSection(mode: $mode, script: $script, showTranslation: $showTranslation, showTajweed: $showTajweed, showJuzProgress: $showJuzProgress)
                WordByWordSettingsSection(followAlong: $followAlong, followAlongTransliteration: $followAlongTransliteration, followAlongMeaning: $followAlongMeaning, script: script)
                FontSizeSettingsSection(arabicFontSize: $arabicFontSize, translationFontSize: $translationFontSize)
                HadithFontSizeSection(hadithArabicFontSize: $hadithArabicFontSize)
                AppearanceSettingsSection(appearanceMode: $appearanceMode)
                AudioSettingsSection(selectedReciter: $selectedReciter, autoAdvance: $followAlongAutoAdvance, loopCount: $followAlongLoopCount)
                PrayerTimesSettingsSection(prayerNotifications: $prayerNotifications)
                DedicationFooter()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .hiddenNavBarBackground()
            .sheet(isPresented: $showGuide) {
                AppGuideView()
            }
        }
    }
}
