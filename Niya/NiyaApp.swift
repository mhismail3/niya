import SwiftUI
import SwiftData

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
    @State private var navigationCoordinator = NavigationCoordinator()

    private let container: ModelContainer

    init() {
        let ds = QuranDataService()
        let hds = HadithDataService()
        let dds = DuaDataService()
        let as_ = AudioService()
        let avm = AudioPlayerViewModel(audioService: as_, dataService: ds)
        let wds = WordDataService()
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
    }

    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

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
                .environment(navigationCoordinator)
                .modelContainer(container)
                .preferredColorScheme(appearanceMode == 0 ? nil : appearanceMode == 1 ? .light : .dark)
        }
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
