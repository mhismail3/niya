import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("QuranDataService Edge Cases")
struct QuranDataServiceEdgeTests {

    private func makeLoadedService() async -> QuranDataService {
        let service = QuranDataService()
        await service.load()
        return service
    }

    @Test func versesForInvalidSurahId() async {
        let service = await makeLoadedService()
        let verses = service.verses(for: 999, script: .hafs)
        #expect(verses.isEmpty)
    }

    @Test func verseForInvalidIds() async {
        let service = await makeLoadedService()
        let verse = service.verse(surahId: 999, ayahId: 999)
        #expect(verse == nil)
    }

    @Test func pagesForInvalidSurah() async {
        let service = await makeLoadedService()
        let pages = service.pages(for: 999, script: .hafs)
        #expect(pages.isEmpty)
    }

    @Test func searchSurahsEmptyQuery() async {
        let service = await makeLoadedService()
        let results = service.searchSurahs(query: "")
        #expect(results.count == 114)
    }

    @Test func searchSurahsNoMatch() async {
        let service = await makeLoadedService()
        let results = service.searchSurahs(query: "xyznotfound")
        #expect(results.isEmpty)
    }

    @Test func absoluteVerseNumber() async {
        let service = await makeLoadedService()
        // Al-Fatihah has 7 verses, so Al-Baqarah ayah 1 = 7 + 1 = 8
        #expect(service.absoluteVerseNumber(surah: 2, ayah: 1) == 8)
    }

    @Test func clearCacheDoesNotCrash() async {
        let service = await makeLoadedService()
        _ = service.verses(for: 1, script: .hafs)
        service.clearCache()
        let afterClear = service.verses(for: 1, script: .hafs)
        #expect(!afterClear.isEmpty)
    }

    @Test func cacheEvictionWithManyAccesses() async {
        let service = await makeLoadedService()
        for surahId in 1...25 {
            let verses = service.verses(for: surahId, script: .hafs)
            #expect(!verses.isEmpty)
        }
        // Verify earlier surahs still work after eviction (cache max is 20)
        let first = service.verses(for: 1, script: .hafs)
        #expect(!first.isEmpty)
    }

    // MARK: - IndoPak-specific tests

    @Test func indoPakVersesLoad() async {
        let service = await makeLoadedService()
        let verses = service.verses(for: 1, script: .indoPak)
        #expect(verses.count == 7)
    }

    @Test func indoPakVersesForAllSurahs() async {
        let service = await makeLoadedService()
        for surahId in 1...114 {
            let verses = service.verses(for: surahId, script: .indoPak)
            #expect(!verses.isEmpty, "IndoPak surah \(surahId) returned no verses")
        }
    }

    @Test func indoPakCacheKeyDistinctFromHafs() async {
        let service = await makeLoadedService()
        let hafsVerses = service.verses(for: 1, script: .hafs)
        let ipVerses = service.verses(for: 1, script: .indoPak)
        #expect(!hafsVerses.isEmpty)
        #expect(!ipVerses.isEmpty)
        #expect(hafsVerses[0].text != ipVerses[0].text,
                "Hafs and IndoPak should return different Arabic text for same surah")
    }

    @Test func indoPakPagesMatchHafs() async {
        let service = await makeLoadedService()
        let hafsPages = service.pages(for: 2, script: .hafs)
        let ipPages = service.pages(for: 2, script: .indoPak)
        #expect(hafsPages.count == ipPages.count, "Page grouping differs between scripts")
    }

    @Test func versesForInvalidSurahReturnsEmpty_indoPak() async {
        let service = await makeLoadedService()
        let verses = service.verses(for: 999, script: .indoPak)
        #expect(verses.isEmpty)
    }
}
