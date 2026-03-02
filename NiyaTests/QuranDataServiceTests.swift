import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("QuranDataService")
struct QuranDataServiceTests {

    private func makeLoadedService() async -> QuranDataService {
        let service = QuranDataService()
        await service.load()
        return service
    }

    @Test func absoluteVerseNumber_alFatiha1() async {
        let service = await makeLoadedService()
        #expect(service.absoluteVerseNumber(surah: 1, ayah: 1) == 1)
    }

    @Test func absoluteVerseNumber_alFatiha7() async {
        let service = await makeLoadedService()
        #expect(service.absoluteVerseNumber(surah: 1, ayah: 7) == 7)
    }

    @Test func absoluteVerseNumber_alBaqarah1() async {
        let service = await makeLoadedService()
        // Al-Fatihah has 7 verses, so Al-Baqarah:1 = 8
        #expect(service.absoluteVerseNumber(surah: 2, ayah: 1) == 8)
    }

    @Test func absoluteVerseNumber_aliImran1() async {
        let service = await makeLoadedService()
        // Al-Fatihah: 7 + Al-Baqarah: 286 = 293, so Ali 'Imran:1 = 294
        #expect(service.absoluteVerseNumber(surah: 3, ayah: 1) == 294)
    }

    @Test func searchSurahs_byName() async {
        let service = await makeLoadedService()
        let results = service.searchSurahs(query: "fatihah")
        #expect(results.count == 1)
        #expect(results[0].id == 1)
    }

    @Test func searchSurahs_byNumber() async {
        let service = await makeLoadedService()
        let results = service.searchSurahs(query: "2")
        #expect(results.count == 1)
        #expect(results[0].id == 2)
    }

    @Test func searchSurahs_byTranslation() async {
        let service = await makeLoadedService()
        let results = service.searchSurahs(query: "cow")
        #expect(results.count == 1)
        #expect(results[0].id == 2)
    }

    @Test func searchSurahs_emptyQuery_returnsAll() async {
        let service = await makeLoadedService()
        let results = service.searchSurahs(query: "")
        #expect(results.count == 114)
    }

    @Test func searchSurahs_noMatch() async {
        let service = await makeLoadedService()
        let results = service.searchSurahs(query: "zzzzz")
        #expect(results.isEmpty)
    }
}
