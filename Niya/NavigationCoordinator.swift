import Foundation

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
    var selectedTab: AppTab = .home
    var isReaderVisible = false
    var pendingQuranDestination: QuranNavDestination?
    var pendingHadithDestination: HadithNavDestination?
    var pendingDuaDestination: DuaNavDestination?
    var showSalahSheet = false
    var currentReadingSurahId: Int?
    var currentReadingAyahId: Int?

    func updateReadingPosition(surahId: Int, ayahId: Int) {
        currentReadingSurahId = surahId
        currentReadingAyahId = ayahId
    }

    func clearReadingPosition() {
        currentReadingSurahId = nil
        currentReadingAyahId = nil
    }

    func navigateToAyah(surahId: Int, ayahId: Int) {
        pendingQuranDestination = QuranNavDestination(surahId: surahId, ayahId: ayahId)
        selectedTab = .quran
    }

    func navigateToHadith(collectionId: String, hadithId: Int, hasGrades: Bool) {
        pendingHadithDestination = HadithNavDestination(collectionId: collectionId, hadithId: hadithId, hasGrades: hasGrades)
        selectedTab = .hadith
    }

    func navigateToDua(categoryId: Int, duaId: Int) {
        pendingDuaDestination = DuaNavDestination(categoryId: categoryId, duaId: duaId)
        selectedTab = .dua
    }
}
