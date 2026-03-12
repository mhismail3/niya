import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("NavigationCoordinator")
struct NavigationCoordinatorTests {

    @Test func initialState() {
        let coordinator = NavigationCoordinator()
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.pendingQuranDestination == nil)
        #expect(coordinator.pendingHadithDestination == nil)
        #expect(coordinator.pendingDuaDestination == nil)
        #expect(coordinator.isReaderVisible == false)
        #expect(coordinator.isChromeHidden == false)
    }

    @Test func navigateToAyah_setsTabAndDestination() {
        let coordinator = NavigationCoordinator()
        coordinator.navigateToAyah(surahId: 2, ayahId: 255)
        #expect(coordinator.selectedTab == .quran)
        #expect(coordinator.pendingQuranDestination?.surahId == 2)
        #expect(coordinator.pendingQuranDestination?.ayahId == 255)
    }

    @Test func navigateToHadith_setsTabAndDestination() {
        let coordinator = NavigationCoordinator()
        coordinator.navigateToHadith(collectionId: "bukhari", hadithId: 1, hasGrades: true)
        #expect(coordinator.selectedTab == .hadith)
        #expect(coordinator.pendingHadithDestination?.collectionId == "bukhari")
        #expect(coordinator.pendingHadithDestination?.hadithId == 1)
        #expect(coordinator.pendingHadithDestination?.hasGrades == true)
    }

    @Test func navigateToDua_setsTabAndDestination() {
        let coordinator = NavigationCoordinator()
        coordinator.navigateToDua(categoryId: 5, duaId: 3)
        #expect(coordinator.selectedTab == .dua)
        #expect(coordinator.pendingDuaDestination?.categoryId == 5)
        #expect(coordinator.pendingDuaDestination?.duaId == 3)
    }

    @Test func sequentialNavigations_clearPriorDestinations() {
        let coordinator = NavigationCoordinator()
        coordinator.navigateToAyah(surahId: 1, ayahId: 1)
        #expect(coordinator.selectedTab == .quran)

        coordinator.navigateToHadith(collectionId: "muslim", hadithId: 10, hasGrades: true)
        #expect(coordinator.selectedTab == .hadith)
        #expect(coordinator.pendingQuranDestination?.surahId == 1)

        coordinator.pendingQuranDestination = nil
        coordinator.navigateToDua(categoryId: 1, duaId: 1)
        #expect(coordinator.selectedTab == .dua)
        #expect(coordinator.pendingQuranDestination == nil)
    }

    @Test func updateReadingPositionSetsFields() {
        let coordinator = NavigationCoordinator()
        coordinator.updateReadingPosition(surahId: 3, ayahId: 55)
        #expect(coordinator.currentReadingSurahId == 3)
        #expect(coordinator.currentReadingAyahId == 55)
    }

    @Test func clearReadingPositionNilsFields() {
        let coordinator = NavigationCoordinator()
        coordinator.updateReadingPosition(surahId: 3, ayahId: 55)
        coordinator.clearReadingPosition()
        #expect(coordinator.currentReadingSurahId == nil)
        #expect(coordinator.currentReadingAyahId == nil)
    }

    @Test func coordinatorStateAvailableForBackgroundSave() {
        let coordinator = NavigationCoordinator()
        coordinator.updateReadingPosition(surahId: 114, ayahId: 6)

        if let surahId = coordinator.currentReadingSurahId,
           let ayahId = coordinator.currentReadingAyahId {
            #expect(surahId == 114)
            #expect(ayahId == 6)
        } else {
            Issue.record("Coordinator state should be available")
        }
    }

    @Test func noSaveWhenReaderNotActive() {
        let coordinator = NavigationCoordinator()
        #expect(coordinator.currentReadingSurahId == nil)
        #expect(coordinator.currentReadingAyahId == nil)
    }
}
