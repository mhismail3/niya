import Foundation
import SwiftData
import Testing
@testable import Niya

@MainActor
@Suite("StoreContainer")
struct StoreContainerTests {

    private func makeContainer() throws -> StoreContainer {
        let cloudConfig = ModelConfiguration(
            "CloudSync",
            schema: Schema([
                QuranBookmark.self, HadithBookmark.self, DuaBookmark.self,
                ReadingPosition.self, RecentHadith.self, RecentDua.self,
                RecentSearch.self,
            ]),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "LocalOnly",
            schema: Schema([AudioDownload.self]),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: QuranBookmark.self, HadithBookmark.self, DuaBookmark.self,
                 ReadingPosition.self, RecentHadith.self, RecentDua.self,
                 RecentSearch.self, AudioDownload.self,
            configurations: cloudConfig, localConfig
        )
        return StoreContainer(modelContext: container.mainContext)
    }

    @Test func defaultContainerExists() throws {
        let stores = try makeContainer()
        #expect(type(of: stores) == StoreContainer.self)
    }

    @Test func allStoresAccessible() throws {
        let stores = try makeContainer()
        #expect(type(of: stores.quranBookmarks) == QuranBookmarkStore.self)
        #expect(type(of: stores.hadithBookmarks) == HadithBookmarkStore.self)
        #expect(type(of: stores.duaBookmarks) == DuaBookmarkStore.self)
        #expect(type(of: stores.readingPosition) == ReadingPositionStore.self)
        #expect(type(of: stores.downloads) == DownloadStore.self)
        #expect(type(of: stores.recentSearch) == RecentSearchStore.self)
        #expect(type(of: stores.recentHadith) == RecentHadithStore.self)
        #expect(type(of: stores.recentDua) == RecentDuaStore.self)
    }

    @Test func multipleContainersAreDistinctInstances() throws {
        let storesA = try makeContainer()
        let storesB = try makeContainer()
        // Verify two containers produce distinct store instances
        // (avoid ModelContext.fetch which crashes in iOS 26 beta test host)
        #expect(storesA.quranBookmarks !== storesB.quranBookmarks)
        #expect(storesA.hadithBookmarks !== storesB.hadithBookmarks)
    }
}
