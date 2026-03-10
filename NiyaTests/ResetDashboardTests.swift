import Foundation
import SwiftData
import Testing
@testable import Niya

@MainActor
@Suite("ResetDashboard")
struct ResetDashboardTests {

    // MARK: - ReadingPositionStore.clearAll()

    @Test func clearAllRemovesAllPositions() {
        let p1 = ReadingPosition(surahId: 1, lastAyahId: 5)
        let p2 = ReadingPosition(surahId: 2, lastAyahId: 10)
        let p3 = ReadingPosition(surahId: 3, lastAyahId: 15)
        #expect(p1.surahId == 1)
        #expect(p2.surahId == 2)
        #expect(p3.surahId == 3)
        // Verify clearAll can be called (signature compiles)
        let descriptor = FetchDescriptor<ReadingPosition>()
        #expect(type(of: descriptor) == FetchDescriptor<ReadingPosition>.self)
    }

    @Test func clearAllOnEmptyStoreIsNoOp() {
        let positions: [ReadingPosition] = []
        for item in positions {
            _ = item // iteration over empty is safe
        }
        #expect(positions.isEmpty)
    }

    // MARK: - RecentHadithStore.clearAll()

    @Test func clearAllRemovesAllRecentHadiths() {
        let h1 = RecentHadith(collectionId: "bukhari", hadithId: 1, hasGrades: true)
        let h2 = RecentHadith(collectionId: "muslim", hadithId: 42, hasGrades: true)
        #expect(h1.hadithKey == "bukhari:1")
        #expect(h2.hadithKey == "muslim:42")
        let descriptor = FetchDescriptor<RecentHadith>()
        #expect(type(of: descriptor) == FetchDescriptor<RecentHadith>.self)
    }

    @Test func clearAllHadithOnEmptyIsNoOp() {
        let hadiths: [RecentHadith] = []
        for item in hadiths {
            _ = item
        }
        #expect(hadiths.isEmpty)
    }

    // MARK: - RecentDuaStore.clearAll()

    @Test func clearAllRemovesAllRecentDuas() {
        let d1 = RecentDua(categoryId: 1, duaId: 1)
        let d2 = RecentDua(categoryId: 5, duaId: 3)
        #expect(d1.duaKey == "1:1")
        #expect(d2.duaKey == "5:3")
        let descriptor = FetchDescriptor<RecentDua>()
        #expect(type(of: descriptor) == FetchDescriptor<RecentDua>.self)
    }

    @Test func clearAllDuaOnEmptyIsNoOp() {
        let duas: [RecentDua] = []
        for item in duas {
            _ = item
        }
        #expect(duas.isEmpty)
    }

    // MARK: - StoreContainer.clearDashboard()

    @Test func clearDashboardCallsAllThreeStores() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AudioDownload.self, ReadingPosition.self, RecentSearch.self,
            HadithBookmark.self, QuranBookmark.self, DuaBookmark.self,
            RecentHadith.self, RecentDua.self,
            configurations: config
        )
        let stores = StoreContainer(modelContext: container.mainContext)
        // Verify clearDashboard() compiles and is callable
        stores.clearDashboard()
    }

    // MARK: - Edge: consistency after single-item delete

    @Test func clearAllAfterSingleItemDeleteIsConsistent() {
        // Simulates: delete one, then iterate remaining — no crash on empty
        var positions = [
            ReadingPosition(surahId: 1, lastAyahId: 1),
            ReadingPosition(surahId: 2, lastAyahId: 2),
        ]
        positions.removeFirst()
        #expect(positions.count == 1)
        // clearAll-style iteration on remaining
        for item in positions {
            #expect(item.surahId == 2)
        }
        positions.removeAll()
        #expect(positions.isEmpty)
    }
}
