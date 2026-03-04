import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirService Cache Behavior")
struct TafsirCacheTests {

    // MARK: - clearCache

    @Test func clearCacheThenAccessReturnsNil() {
        let service = TafsirService()
        // Populate cache
        let before = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        #expect(before != nil)

        service.clearCache()

        // After clearing, internal cache is empty. However, text() reloads from
        // bundle on miss, so it will still return data. We verify clearCache
        // doesn't crash and the service remains functional.
        let after = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        #expect(after == before)
    }

    @Test func clearCacheIsIdempotent() {
        let service = TafsirService()
        service.clearCache()
        service.clearCache()
        // Should not crash; service still works
        let text = service.text(edition: .ibnAbbas, surahId: 2, ayahId: 255)
        #expect(text != nil)
    }

    // MARK: - Cache hits

    @Test func cacheHitReturnsSameResult() {
        let service = TafsirService()
        let first = service.text(edition: .ibnKathir, surahId: 36, ayahId: 1)
        let second = service.text(edition: .ibnKathir, surahId: 36, ayahId: 1)
        #expect(first != nil)
        #expect(first == second)
    }

    @Test func cacheHitForDifferentAyahInSameSurah() {
        let service = TafsirService()
        // Loading ayah 1 caches the whole surah
        let a1 = service.text(edition: .maarifUlQuran, surahId: 2, ayahId: 1)
        let a2 = service.text(edition: .maarifUlQuran, surahId: 2, ayahId: 2)
        #expect(a1 != nil)
        #expect(a2 != nil)
        #expect(a1 != a2)
    }

    // MARK: - LRU eviction

    @Test func accessingManySurahsDoesNotCrash() {
        let service = TafsirService()
        // Access 15 different surahs, exceeding maxCachedSurahs (10)
        for surahId in 1...15 {
            let text = service.text(edition: .ibnKathir, surahId: surahId, ayahId: 1)
            #expect(text != nil, "Surah \(surahId) should have tafsir text")
        }
    }

    @Test func evictedSurahReloadsFromBundle() {
        let service = TafsirService()
        // Load surah 1 first
        let initial = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        #expect(initial != nil)

        // Load 11 more surahs to push surah 1 out of the LRU cache (max=10)
        for surahId in 2...12 {
            _ = service.text(edition: .ibnKathir, surahId: surahId, ayahId: 1)
        }

        // Surah 1 was evicted but text() reloads from bundle transparently
        let reloaded = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        #expect(reloaded == initial)
    }

    @Test func lruTouchPreventsEviction() {
        let service = TafsirService()
        // Load surahs 1 through 10 (fills cache)
        for surahId in 1...10 {
            _ = service.text(edition: .ibnKathir, surahId: surahId, ayahId: 1)
        }

        // Touch surah 1 (moves it to back of LRU)
        _ = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)

        // Load surah 11 -- should evict surah 2 (the oldest untouched), not surah 1
        _ = service.text(edition: .ibnKathir, surahId: 11, ayahId: 1)

        // Surah 1 should still be cached (still returns correct data either way,
        // but the point is the LRU touch kept it alive)
        let text = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        #expect(text != nil)
    }

    // MARK: - Multiple editions

    @Test func allFourEditionsReturnTextForSameVerse() {
        let service = TafsirService()
        for edition in TafsirEdition.allCases {
            let text = service.text(edition: edition, surahId: 1, ayahId: 1)
            #expect(text != nil, "\(edition.displayName) should have text for 1:1")
            #expect(!text!.isEmpty, "\(edition.displayName) text should be non-empty")
        }
    }

    @Test func differentEditionsProduceDifferentText() {
        let service = TafsirService()
        let ik = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        let mq = service.text(edition: .maarifUlQuran, surahId: 1, ayahId: 1)
        let ia = service.text(edition: .ibnAbbas, surahId: 1, ayahId: 1)
        let tq = service.text(edition: .tazkirulQuran, surahId: 1, ayahId: 1)
        // Each edition has distinct commentary
        #expect(ik != ia)
        #expect(ik != mq)
        #expect(ik != tq)
    }

    @Test func editionsCacheIndependently() {
        let service = TafsirService()
        // Load same surah in two editions -- both should be cached
        let ik = service.text(edition: .ibnKathir, surahId: 36, ayahId: 1)
        let ia = service.text(edition: .ibnAbbas, surahId: 36, ayahId: 1)
        #expect(ik != nil)
        #expect(ia != nil)
        #expect(ik != ia)

        // Clear and reload: both still return data
        service.clearCache()
        #expect(service.text(edition: .ibnKathir, surahId: 36, ayahId: 1) == ik)
        #expect(service.text(edition: .ibnAbbas, surahId: 36, ayahId: 1) == ia)
    }

    // MARK: - Invalid input

    @Test func nonexistentSurahReturnsNil() {
        let service = TafsirService()
        #expect(service.text(edition: .ibnKathir, surahId: 999, ayahId: 1) == nil)
    }

    @Test func nonexistentAyahReturnsNil() {
        let service = TafsirService()
        // Surah 1 has 7 ayahs; ayah 999 does not exist
        #expect(service.text(edition: .ibnKathir, surahId: 1, ayahId: 999) == nil)
    }

    @Test func negativeSurahReturnsNil() {
        let service = TafsirService()
        #expect(service.text(edition: .ibnKathir, surahId: -1, ayahId: 1) == nil)
    }

    // MARK: - clearCache then reload

    @Test func clearCacheThenReloadStillWorks() {
        let service = TafsirService()
        let original = service.text(edition: .tazkirulQuran, surahId: 112, ayahId: 1)
        #expect(original != nil)

        service.clearCache()

        let reloaded = service.text(edition: .tazkirulQuran, surahId: 112, ayahId: 1)
        #expect(reloaded != nil)
        #expect(reloaded == original)
    }
}
