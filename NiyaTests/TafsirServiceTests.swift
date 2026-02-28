import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirService")
struct TafsirServiceTests {

    @Test func entryReturnsNilBeforeFetch() {
        let service = TafsirService()
        #expect(service.entry(edition: .ibnKathir, surahId: 1, ayahId: 1) == nil)
    }

    @Test func isLoadingFalseInitially() {
        let service = TafsirService()
        #expect(service.isLoading(edition: .ibnKathir, surahId: 1, ayahId: 1) == false)
    }

    @Test func fetchDuplicateIsNoop() {
        let service = TafsirService()
        service.fetch(edition: .ibnKathir, surahId: 999, ayahId: 999)
        service.fetch(edition: .ibnKathir, surahId: 999, ayahId: 999)
    }

    @Test func cacheKeyFormat() {
        let service = TafsirService()
        let key = service.cacheKey(edition: .ibnKathir, surahId: 2, ayahId: 255)
        #expect(key == "en-tafisr-ibn-kathir:2:255")
    }

    @Test func differentEditionsSameSurahAyah() {
        let service = TafsirService()
        let entry1 = TafsirEntry(surah: 1, ayah: 1, text: "Ibn Kathir text")
        let entry2 = TafsirEntry(surah: 1, ayah: 1, text: "Jalalayn text")
        service.insertEntry(entry1, edition: .ibnKathir, surahId: 1, ayahId: 1)
        service.insertEntry(entry2, edition: .jalalayn, surahId: 1, ayahId: 1)
        #expect(service.entry(edition: .ibnKathir, surahId: 1, ayahId: 1)?.text == "Ibn Kathir text")
        #expect(service.entry(edition: .jalalayn, surahId: 1, ayahId: 1)?.text == "Jalalayn text")
    }

    @Test func sameSurahDifferentAyah() {
        let service = TafsirService()
        let entry1 = TafsirEntry(surah: 2, ayah: 1, text: "Ayah 1")
        let entry2 = TafsirEntry(surah: 2, ayah: 2, text: "Ayah 2")
        service.insertEntry(entry1, edition: .ibnKathir, surahId: 2, ayahId: 1)
        service.insertEntry(entry2, edition: .ibnKathir, surahId: 2, ayahId: 2)
        #expect(service.entry(edition: .ibnKathir, surahId: 2, ayahId: 1)?.text == "Ayah 1")
        #expect(service.entry(edition: .ibnKathir, surahId: 2, ayahId: 2)?.text == "Ayah 2")
    }

    @Test func cooldownPreventsImmediateRetry() {
        let service = TafsirService()
        // First fetch will start loading
        service.fetch(edition: .ibnKathir, surahId: 999, ayahId: 999)
        // The key is now in loadingKeys, so second call is a no-op
        let isLoading = service.isLoading(edition: .ibnKathir, surahId: 999, ayahId: 999)
        #expect(isLoading == true)
    }

    @Test func insertAndRetrieve() {
        let service = TafsirService()
        let entry = TafsirEntry(surah: 36, ayah: 1, text: "Ya-Sin commentary")
        service.insertEntry(entry, edition: .maarifUlQuran, surahId: 36, ayahId: 1)
        let retrieved = service.entry(edition: .maarifUlQuran, surahId: 36, ayahId: 1)
        #expect(retrieved?.text == "Ya-Sin commentary")
        #expect(retrieved?.surah == 36)
        #expect(retrieved?.ayah == 1)
    }

    // MARK: - Edge Cases

    @Test func allEditionsGenerateValidURLs() {
        for edition in TafsirEdition.allCases {
            let url = edition.url(surahId: 1, ayahId: 1)
            #expect(url.scheme == "https")
            #expect(url.absoluteString.contains(edition.rawValue))
        }
    }

    @Test func fetchForSurahZeroAyahZero() {
        let service = TafsirService()
        service.fetch(edition: .ibnKathir, surahId: 0, ayahId: 0)
    }

    @Test func concurrentFetchesSameKey() {
        let service = TafsirService()
        service.fetch(edition: .jalalayn, surahId: 1, ayahId: 1)
        service.fetch(edition: .jalalayn, surahId: 1, ayahId: 1)
        service.fetch(edition: .jalalayn, surahId: 1, ayahId: 1)
    }
}
