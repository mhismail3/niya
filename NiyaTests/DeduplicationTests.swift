import Foundation
import SwiftData
import Testing
@testable import Niya

@MainActor
@Suite("Deduplication")
struct DeduplicationTests {

    // MARK: - QuranBookmark dedup

    @Test func quranDedupKeepsEarliestCreatedAt() {
        let older = QuranBookmark(surahId: 2, ayahId: 255, createdAt: Date(timeIntervalSince1970: 1000))
        let newer = QuranBookmark(surahId: 2, ayahId: 255, createdAt: Date(timeIntervalSince1970: 2000))
        let matches = [newer, older]
        let keeper = matches.min(by: { $0.createdAt < $1.createdAt })
        #expect(keeper === older)
    }

    @Test func quranDedupOnUniqueKeysIsNoOp() {
        let a = QuranBookmark(surahId: 1, ayahId: 1)
        let b = QuranBookmark(surahId: 2, ayahId: 255)
        let all = [a, b]
        var seen = Set<String>()
        var result: [QuranBookmark] = []
        for item in all {
            if seen.insert(item.verseKey).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 2)
    }

    // MARK: - HadithBookmark dedup

    @Test func hadithDedupKeepsEarliestCreatedAt() {
        let older = HadithBookmark(collectionId: "bukhari", hadithId: 1, createdAt: Date(timeIntervalSince1970: 1000))
        let newer = HadithBookmark(collectionId: "bukhari", hadithId: 1, createdAt: Date(timeIntervalSince1970: 2000))
        let matches = [newer, older]
        let keeper = matches.min(by: { $0.createdAt < $1.createdAt })
        #expect(keeper === older)
    }

    @Test func hadithDedupOnUniqueKeysIsNoOp() {
        let a = HadithBookmark(collectionId: "bukhari", hadithId: 1)
        let b = HadithBookmark(collectionId: "muslim", hadithId: 42)
        let all = [a, b]
        var seen = Set<String>()
        var result: [HadithBookmark] = []
        for item in all {
            if seen.insert(item.hadithKey).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 2)
    }

    // MARK: - DuaBookmark dedup

    @Test func duaDedupKeepsEarliestCreatedAt() {
        let older = DuaBookmark(categoryId: "cat-1", duaId: "dua-1", createdAt: Date(timeIntervalSince1970: 1000))
        let newer = DuaBookmark(categoryId: "cat-1", duaId: "dua-1", createdAt: Date(timeIntervalSince1970: 2000))
        let matches = [newer, older]
        let keeper = matches.min(by: { $0.createdAt < $1.createdAt })
        #expect(keeper === older)
    }

    @Test func duaDedupOnUniqueKeysIsNoOp() {
        let a = DuaBookmark(categoryId: "cat-1", duaId: "dua-1")
        let b = DuaBookmark(categoryId: "cat-5", duaId: "dua-3")
        let all = [a, b]
        var seen = Set<String>()
        var result: [DuaBookmark] = []
        for item in all {
            if seen.insert(item.duaKey).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 2)
    }

    // MARK: - ReadingPosition dedup

    @Test func positionDedupKeepsMostRecentReadAt() {
        let older = ReadingPosition(surahId: 36, lastAyahId: 5, lastReadAt: Date(timeIntervalSince1970: 1000))
        let newer = ReadingPosition(surahId: 36, lastAyahId: 12, lastReadAt: Date(timeIntervalSince1970: 2000))
        let matches = [older, newer]
        let keeper = matches.max(by: { $0.lastReadAt < $1.lastReadAt })
        #expect(keeper === newer)
        #expect(keeper?.lastAyahId == 12)
    }

    @Test func positionDedupOnUniqueSurahsIsNoOp() {
        let a = ReadingPosition(surahId: 1, lastAyahId: 1)
        let b = ReadingPosition(surahId: 36, lastAyahId: 5)
        let all = [a, b]
        var seen = Set<Int>()
        var result: [ReadingPosition] = []
        for item in all {
            if seen.insert(item.surahId).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 2)
    }

    // MARK: - RecentHadith dedup

    @Test func recentHadithDedupKeepsMostRecentVisitedAt() {
        let older = RecentHadith(collectionId: "bukhari", hadithId: 1, hasGrades: true, visitedAt: Date(timeIntervalSince1970: 1000))
        let newer = RecentHadith(collectionId: "bukhari", hadithId: 1, hasGrades: true, visitedAt: Date(timeIntervalSince1970: 2000))
        let matches = [older, newer]
        let keeper = matches.max(by: { $0.visitedAt < $1.visitedAt })
        #expect(keeper === newer)
    }

    @Test func recentHadithDedupOnUniqueKeysIsNoOp() {
        let a = RecentHadith(collectionId: "bukhari", hadithId: 1, hasGrades: true)
        let b = RecentHadith(collectionId: "muslim", hadithId: 42, hasGrades: true)
        let all = [a, b]
        var seen = Set<String>()
        var result: [RecentHadith] = []
        for item in all {
            if seen.insert(item.hadithKey).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 2)
    }

    // MARK: - RecentDua dedup

    @Test func recentDuaDedupKeepsMostRecentVisitedAt() {
        let older = RecentDua(categoryId: "cat-1", duaId: "dua-1", visitedAt: Date(timeIntervalSince1970: 1000))
        let newer = RecentDua(categoryId: "cat-1", duaId: "dua-1", visitedAt: Date(timeIntervalSince1970: 2000))
        let matches = [older, newer]
        let keeper = matches.max(by: { $0.visitedAt < $1.visitedAt })
        #expect(keeper === newer)
    }

    @Test func recentDuaDedupOnUniqueKeysIsNoOp() {
        let a = RecentDua(categoryId: "cat-1", duaId: "dua-1")
        let b = RecentDua(categoryId: "cat-5", duaId: "dua-3")
        let all = [a, b]
        var seen = Set<String>()
        var result: [RecentDua] = []
        for item in all {
            if seen.insert(item.duaKey).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 2)
    }

    // MARK: - Edge cases

    @Test func dedupOnEmptyArrayIsNoOp() {
        let items: [QuranBookmark] = []
        var seen = Set<String>()
        var result: [QuranBookmark] = []
        for item in items {
            if seen.insert(item.verseKey).inserted {
                result.append(item)
            }
        }
        #expect(result.isEmpty)
    }

    @Test func dedupOnSingleItemIsNoOp() {
        let bm = QuranBookmark(surahId: 1, ayahId: 1)
        let items = [bm]
        var seen = Set<String>()
        var result: [QuranBookmark] = []
        for item in items {
            if seen.insert(item.verseKey).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 1)
    }

    @Test func dedupOnThreeDuplicatesKeepsOne() {
        let a = QuranBookmark(surahId: 2, ayahId: 255, createdAt: Date(timeIntervalSince1970: 3000))
        let b = QuranBookmark(surahId: 2, ayahId: 255, createdAt: Date(timeIntervalSince1970: 1000))
        let c = QuranBookmark(surahId: 2, ayahId: 255, createdAt: Date(timeIntervalSince1970: 2000))
        let items = [a, b, c].sorted { $0.createdAt < $1.createdAt }
        var seen = Set<String>()
        var result: [QuranBookmark] = []
        for item in items {
            if seen.insert(item.verseKey).inserted {
                result.append(item)
            }
        }
        #expect(result.count == 1)
        #expect(result.first === b)
    }
}
