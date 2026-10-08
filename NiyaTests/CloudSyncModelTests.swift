import Foundation
import SwiftData
import Testing
@testable import Niya

@MainActor
@Suite("CloudSyncModels")
struct CloudSyncModelTests {

    @Test func quranBookmarkHasDefaultValues() {
        let bm = QuranBookmark(surahId: 2, ayahId: 255)
        #expect(bm.verseKey == "2:255")
        #expect(bm.surahId == 2)
        #expect(bm.ayahId == 255)
        #expect(bm.createdAt <= .now)
        #expect(bm.colorTag == nil)
    }

    @Test func hadithBookmarkHasDefaultValues() {
        let bm = HadithBookmark(collectionId: "bukhari", hadithId: 1)
        #expect(bm.hadithKey == "bukhari:1")
        #expect(bm.collectionId == "bukhari")
        #expect(bm.hadithId == 1)
        #expect(bm.createdAt <= .now)
        #expect(bm.colorTag == nil)
    }

    @Test func duaBookmarkHasDefaultValues() {
        let bm = DuaBookmark(categoryId: "cat-5", duaId: "dua-3")
        #expect(bm.duaKey == "cat-5:dua-3")
        #expect(bm.categorySlug == "cat-5")
        #expect(bm.duaStringId == "dua-3")
        #expect(bm.createdAt <= Date.now)
        #expect(bm.colorTag == nil)
    }

    @Test func readingPositionHasDefaultValues() {
        let pos = ReadingPosition(surahId: 36, lastAyahId: 12)
        #expect(pos.surahId == 36)
        #expect(pos.lastAyahId == 12)
        #expect(pos.lastReadAt <= .now)
    }

    @Test func recentHadithHasDefaultValues() {
        let rh = RecentHadith(collectionId: "muslim", hadithId: 42, hasGrades: true)
        #expect(rh.hadithKey == "muslim:42")
        #expect(rh.collectionId == "muslim")
        #expect(rh.hadithId == 42)
        #expect(rh.hasGrades == true)
        #expect(rh.visitedAt <= .now)
    }

    @Test func recentDuaHasDefaultValues() {
        let rd = RecentDua(categoryId: "cat-1", duaId: "dua-7")
        #expect(rd.duaKey == "cat-1:dua-7")
        #expect(rd.categorySlug == "cat-1")
        #expect(rd.duaStringId == "dua-7")
        #expect(rd.visitedAt <= Date.now)
    }

    @Test func recentSearchHasDefaultValues() {
        let rs = RecentSearch(query: "mercy")
        #expect(rs.query == "mercy")
        #expect(rs.surahId == nil)
        #expect(rs.createdAt <= .now)
    }

    /// Re-downloadable audio must never sync to iCloud; user data must.
    @Test func onlyUserDataSyncsToCloudKit() {
        let synced = Set(ModelContainerFactory.syncedModels.map { ObjectIdentifier($0) })
        let local = Set(ModelContainerFactory.localModels.map { ObjectIdentifier($0) })
        #expect(local == [ObjectIdentifier(AudioDownload.self)])
        #expect(synced.isDisjoint(with: local))
        let expected: [any PersistentModel.Type] = [
            QuranBookmark.self, HadithBookmark.self, DuaBookmark.self, ReadingPosition.self,
            RecentHadith.self, RecentDua.self, RecentSearch.self,
        ]
        #expect(synced == Set(expected.map { ObjectIdentifier($0) }))
    }

    @Test func factoryContainerRoundTripsBothStores() throws {
        let container = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)
        let context = ModelContext(container)
        context.insert(QuranBookmark(surahId: 1, ayahId: 1))
        context.insert(AudioDownload(surahId: 1, localFileName: "a.mp3", reciterId: "alafasy"))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<QuranBookmark>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<AudioDownload>()) == 1)
    }
}
