import Foundation
import SwiftData
import Testing
@testable import Niya

/// CloudKit can deliver the same record from several devices; stores must behave as if
/// each key exists once, and bounded tables must stay bounded.
@MainActor
@Suite("Deduplication and bounds")
struct DeduplicationTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)
    }

    @Test func togglingOffRemovesEverySyncedDuplicate() throws {
        for offset in 0..<3 {
            context.insert(QuranBookmark(surahId: 2, ayahId: 255, createdAt: Date(timeIntervalSince1970: Double(offset))))
        }
        try context.save()
        let store = QuranBookmarkStore(modelContext: context)

        store.toggle(surahId: 2, ayahId: 255)

        #expect(!store.isBookmarked(surahId: 2, ayahId: 255))
        #expect(try context.fetchCount(FetchDescriptor<QuranBookmark>()) == 0)
    }

    @Test func readingPositionUsesNewestOfManyDuplicates() throws {
        for (ayah, time) in [(10, 100.0), (40, 300.0), (20, 200.0)] {
            context.insert(ReadingPosition(surahId: 18, lastAyahId: ayah, lastReadAt: Date(timeIntervalSince1970: time)))
        }
        try context.save()

        #expect(ReadingPositionStore(modelContext: context).position(for: 18)?.lastAyahId == 40)
    }

    @Test func recentHadithsStayBoundedAndNewestFirst() {
        let store = RecentHadithStore(modelContext: context)
        for id in 1...(RecentHadithStore.retainedCount + 10) {
            store.record(collectionId: "bukhari", hadithId: id, hasGrades: false)
        }

        #expect((try? context.fetchCount(FetchDescriptor<RecentHadith>())) == RecentHadithStore.retainedCount)
        #expect(store.recentHadiths(limit: 1).first?.hadithId == RecentHadithStore.retainedCount + 10)
    }

    @Test func recentDuasStayBounded() {
        let store = RecentDuaStore(modelContext: context)
        for id in 1...(RecentDuaStore.retainedCount + 5) {
            store.record(categoryId: "morning", duaId: "dua-\(id)")
        }

        #expect((try? context.fetchCount(FetchDescriptor<RecentDua>())) == RecentDuaStore.retainedCount)
    }

    @Test func redownloadUpdatesTheExistingRecord() throws {
        let store = DownloadStore(modelContext: context)
        try store.save(surahId: 36, filename: "old.mp3", reciterId: "alafasy")
        try store.save(surahId: 36, filename: "new.mp3", reciterId: "alafasy")

        let records = try store.allDownloads()
        #expect(records.map(\.localFileName) == ["new.mp3"])
    }
}
