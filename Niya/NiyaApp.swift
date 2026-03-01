import SwiftUI
import SwiftData
import TipKit
import UserNotifications

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

    private let container: ModelContainer

    init() {
        let ds = QuranDataService()
        let hds = HadithDataService()
        let dds = DuaDataService()
        let as_ = AudioService()
        let wds = WordDataService()
        let storedReciter = Reciter(rawValue: UserDefaults.standard.string(forKey: "selectedReciter") ?? "") ?? .alAfasy
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

        as_.configureSession()
        Self.migrateAudioFilenames()
        try? Tips.configure([.displayFrequency(.immediate)])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @AppStorage("selectedReciter") private var selectedReciter: Reciter = .alAfasy

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
                .modelContainer(container)
                .preferredColorScheme(appearanceMode == 0 ? nil : appearanceMode == 1 ? .light : .dark)
                .task {
                    await wordDataService.load(reciter: selectedReciter)
                }
                .onChange(of: selectedReciter) { _, newReciter in
                    audioPlayerVM.stop()
                    audioPlayerVM.selectedReciter = newReciter
                    Task { await wordDataService.load(reciter: newReciter) }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        prayerTimeService.checkDayChange(location: locationService.effectiveLocation)
                    }
                }
        }
    }

    private static func migrateAudioFilenames() {
        guard !UserDefaults.standard.bool(forKey: "audioFilenameMigrated") else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fm = FileManager.default
        for surahId in 1...114 {
            let old = docs.appendingPathComponent("audio_surah_\(surahId).mp3")
            let new = docs.appendingPathComponent("audio_alafasy_surah_\(surahId).mp3")
            if fm.fileExists(atPath: old.path) && !fm.fileExists(atPath: new.path) {
                try? fm.moveItem(at: old, to: new)
            }
        }
        UserDefaults.standard.set(true, forKey: "audioFilenameMigrated")
    }
}

struct QuranNavDestination: Hashable {
    let surahId: Int
    let ayahId: Int?

    init(surahId: Int, ayahId: Int? = nil) {
        self.surahId = surahId
        self.ayahId = ayahId
    }
}

struct HadithNavDestination: Hashable {
    let collectionId: String
    let hadithId: Int
    let hasGrades: Bool
}

struct DuaNavDestination: Hashable {
    let categoryId: Int
    let duaId: Int
}

@Observable
@MainActor
final class NavigationCoordinator {
    var selectedTab: String = "home"
    var pendingQuranDestination: QuranNavDestination?
    var pendingHadithDestination: HadithNavDestination?
    var pendingDuaDestination: DuaNavDestination?

    func navigateToAyah(surahId: Int, ayahId: Int) {
        pendingQuranDestination = QuranNavDestination(surahId: surahId, ayahId: ayahId)
        selectedTab = "quran"
    }

    func navigateToHadith(collectionId: String, hadithId: Int, hasGrades: Bool) {
        pendingHadithDestination = HadithNavDestination(collectionId: collectionId, hadithId: hadithId, hasGrades: hasGrades)
        selectedTab = "hadith"
    }

    func navigateToDua(categoryId: Int, duaId: Int) {
        pendingDuaDestination = DuaNavDestination(categoryId: categoryId, duaId: duaId)
        selectedTab = "dua"
    }
}
