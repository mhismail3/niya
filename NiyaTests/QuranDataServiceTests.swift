import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("QuranDataService", .serialized)
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

    @Test func addTranslation_isIdempotentUnderConcurrency() async throws {
        let service = await makeLoadedService()
        guard let clearQuran = service.availableTranslations.first(where: { $0.id == "en_clearquran" }) else {
            Issue.record("Expected en_clearquran in availableTranslations")
            return
        }
        // Two concurrent adds of the same edition must result in exactly one entry.
        async let a: () = try service.addTranslation(clearQuran)
        async let b: () = try service.addTranslation(clearQuran)
        _ = try await (a, b)
        let matching = service.selectedTranslations.filter { $0.id == clearQuran.id }
        #expect(matching.count == 1)
    }

    @Test func load_deduplicatesSavedIds() async {
        UserDefaults.standard.set("en_sahih,en_sahih,en_clearquran", forKey: StorageKey.selectedTranslations)
        defer { UserDefaults.standard.removeObject(forKey: StorageKey.selectedTranslations) }
        let service = await makeLoadedService()
        #expect(service.selectedTranslations.count == 2)
        #expect(service.selectedTranslations.map(\.id) == ["en_sahih", "en_clearquran"])
    }
}
