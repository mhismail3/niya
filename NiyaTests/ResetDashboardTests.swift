import SwiftData
import Testing
@testable import Niya

@MainActor
@Suite("ResetDashboard")
struct ResetDashboardTests {
    @Test func clearDashboardRemovesPositionsAndRecentsButKeepsBookmarks() throws {
        let container = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)
        let context = container.mainContext
        let quranBookmark = QuranBookmark(surahId: 1, ayahId: 2)
        let hadithBookmark = HadithBookmark(collectionId: "bukhari", hadithId: 1)
        let duaBookmark = DuaBookmark(categoryId: "morning", duaId: "1")
        context.insert(quranBookmark)
        context.insert(hadithBookmark)
        context.insert(duaBookmark)
        context.insert(ReadingPosition(surahId: 1, lastAyahId: 2))
        context.insert(RecentHadith(collectionId: "bukhari", hadithId: 1, hasGrades: true))
        context.insert(RecentDua(categoryId: "morning", duaId: "1"))
        try context.save()

        StoreContainer(modelContext: context).clearDashboard()

        #expect(try context.fetch(FetchDescriptor<ReadingPosition>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RecentHadith>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RecentDua>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<QuranBookmark>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HadithBookmark>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<DuaBookmark>()).count == 1)
    }
}
