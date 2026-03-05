import SwiftUI
import SwiftData
import TipKit
import UserNotifications
import UIKit
import WidgetKit

@main
struct NiyaApp: App {
    @State private var dataService = QuranDataService()
    @State private var hadithDataService = HadithDataService()
    @State private var duaDataService = DuaDataService()
    @State private var audioService = AudioService()
    @State private var audioPlayerVM: AudioPlayerViewModel
    @State private var wordDataService = WordDataService()
    @State private var followAlongVM: FollowAlongViewModel
    @State private var tajweedService = TajweedService()
    @State private var tafsirService = TafsirService()
    @State private var navigationCoordinator = NavigationCoordinator()
    @State private var locationService = LocationService()
    @State private var prayerTimeService = PrayerTimeService()
    @State private var autoScrollVM = AutoScrollViewModel()
    @State private var downloadManager: DownloadManager
    @State private var storeContainer: StoreContainer

    private let container: ModelContainer

    init() {
        let ds = QuranDataService()
        let hds = HadithDataService()
        let dds = DuaDataService()
        let as_ = AudioService()
        let wds = WordDataService()
        let storedReciter = Reciter(rawValue: UserDefaults.standard.string(forKey: StorageKey.selectedReciter) ?? "") ?? .alAfasy
        let avm = AudioPlayerViewModel(audioService: as_, dataService: ds, wordDataService: wds, reciter: storedReciter)
        let favm = FollowAlongViewModel(audioService: as_, wordDataService: wds, dataService: ds)
        _dataService = State(wrappedValue: ds)
        _hadithDataService = State(wrappedValue: hds)
        _duaDataService = State(wrappedValue: dds)
        _audioService = State(wrappedValue: as_)
        _audioPlayerVM = State(wrappedValue: avm)
        _wordDataService = State(wrappedValue: wds)
        _followAlongVM = State(wrappedValue: favm)

        do {
            container = try ModelContainer(for: AudioDownload.self, ReadingPosition.self, RecentSearch.self, HadithBookmark.self, QuranBookmark.self, DuaBookmark.self, RecentHadith.self, RecentDua.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let sc = StoreContainer(modelContext: container.mainContext)
        _storeContainer = State(wrappedValue: sc)

        let dm = DownloadManager(downloadStore: sc.downloads)
        dm.reconcile()
        _downloadManager = State(wrappedValue: dm)

        as_.configureSession()
        Self.migrateAudioFilenames()
        try? Tips.configure([.displayFrequency(.immediate)])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(StorageKey.appearanceMode) private var appearanceMode: Int = 0
    @AppStorage(StorageKey.selectedReciter) private var selectedReciter: Reciter = .alAfasy

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataService)
                .environment(hadithDataService)
                .environment(duaDataService)
                .environment(audioService)
                .environment(audioPlayerVM)
                .environment(wordDataService)
                .environment(followAlongVM)
                .environment(tajweedService)
                .environment(tafsirService)
                .environment(navigationCoordinator)
                .environment(locationService)
                .environment(prayerTimeService)
                .environment(autoScrollVM)
                .environment(downloadManager)
                .environment(\.stores, storeContainer)
                .modelContainer(container)
                .accentColor(Color.niyaTeal)
                .preferredColorScheme(appearanceMode == 0 ? nil : appearanceMode == 1 ? .light : .dark)
                .task {
                    await wordDataService.load(reciter: selectedReciter)
                    let lang = dataService.selectedTranslations.first?.language ?? "en"
                    await wordDataService.loadMeanings(language: lang)
                }
                .onChange(of: selectedReciter) { _, newReciter in
                    audioPlayerVM.stop()
                    audioPlayerVM.selectedReciter = newReciter
                    Task { await wordDataService.load(reciter: newReciter) }
                }
                .onChange(of: dataService.selectedTranslations) {
                    let lang = dataService.selectedTranslations.first?.language ?? "en"
                    Task { await wordDataService.loadMeanings(language: lang) }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        prayerTimeService.checkDayChange(location: locationService.effectiveLocation)
                        prayerTimeService.startCountdown()
                        if let loc = locationService.effectiveLocation, let today = prayerTimeService.todayTimes {
                            let asr = max(1, UserDefaults.standard.integer(forKey: StorageKey.asrJuristic))
                            WidgetDataWriter.shared.write(today: today, tomorrow: prayerTimeService.tomorrowTimes, location: loc, asrFactor: asr)
                            WidgetDataWriter.shared.reloadTimelines()
                        }
                    } else if phase == .background {
                        prayerTimeService.stopCountdown()
                    }
                }
                .onOpenURL { url in
                    if url.scheme == "niya" && url.host == "salah" {
                        navigationCoordinator.showSalahSheet = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    dataService.clearCache()
                    tafsirService.clearCache()
                    tajweedService.clearCache()
                }
        }
    }

    private static func migrateAudioFilenames() {
        guard !UserDefaults.standard.bool(forKey: StorageKey.audioFilenameMigrated) else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fm = FileManager.default
        for surahId in 1...114 {
            let old = docs.appendingPathComponent("audio_surah_\(surahId).mp3")
            let new = docs.appendingPathComponent("audio_alafasy_surah_\(surahId).mp3")
            if fm.fileExists(atPath: old.path) && !fm.fileExists(atPath: new.path) {
                try? fm.moveItem(at: old, to: new)
            }
        }
        UserDefaults.standard.set(true, forKey: StorageKey.audioFilenameMigrated)
    }
}
