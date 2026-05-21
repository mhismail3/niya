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

@MainActor
@Suite("SearchIndex", .serialized)
struct SearchIndexTests {

    @Test func normalizerFoldsEnglishPunctuationAndDiacritics() {
        let normalized = SearchTextNormalizer.normalize("  Café—MERCY!  ")
        #expect(normalized == "cafe mercy")
    }

    @Test func normalizerRemovesArabicMarksAndNormalizesAlef() {
        let normalized = SearchTextNormalizer.normalize("ٱللّٰهُ")
        #expect(normalized == "الله")
    }

    @Test func queryParsesSurahNumberAndAyahReference() {
        let number = SearchQuery("2")
        #expect(number.surahNumber == 2)
        #expect(number.reference == nil)

        let reference = SearchQuery("2:255")
        #expect(reference.surahNumber == nil)
        #expect(reference.reference == QuranReference(surahId: 2, ayahId: 255))
    }

    @Test func quranPhraseSearchFindsSelectedTranslationVerse() async {
        let snapshot = await makeLoadedSnapshot()
        let index = SearchIndex()
        await index.configure(snapshot: snapshot)

        let results = await index.search(query: "And rely upon")

        #expect(results.quranVerses.contains { $0.surahId == 25 && $0.ayahId == 58 })
        #expect(results.quranVerses.count <= SearchResultLimits.quranVerses)
    }

    @Test func quranReferenceSearchFindsExactAyah() async {
        let snapshot = await makeLoadedSnapshot()
        let index = SearchIndex()
        await index.configure(snapshot: snapshot)

        let results = await index.search(query: "2:255")

        #expect(results.quranVerses.first?.surahId == 2)
        #expect(results.quranVerses.first?.ayahId == 255)
    }

    @Test func arabicAyahSearchMatchesNormalizedText() async {
        let snapshot = await makeLoadedSnapshot()
        let index = SearchIndex()
        await index.configure(snapshot: snapshot)

        let results = await index.search(query: "الرحمن الرحيم")

        #expect(results.quranVerses.contains { $0.surahId == 1 && $0.ayahId == 3 })
    }

    @Test func hadithSearchDoesNotDependOnLoadedCollectionState() async throws {
        let hadithService = HadithDataService()
        await hadithService.load()
        #expect(hadithService.loadedCollectionCount == 0)

        let snapshot = SearchContentSnapshot(
            quran: QuranSearchSnapshot(surahs: [], verses: []),
            hadithCollections: hadithService.searchCollectionsSnapshot(),
            duas: []
        )
        let index = SearchIndex()
        await index.configure(snapshot: snapshot)

        var results = await index.search(query: "prayer")
        for _ in 0..<100 where results.hadiths.isEmpty && results.isHadithIndexing {
            try await Task.sleep(for: .milliseconds(100))
            results = await index.search(query: "prayer")
        }

        #expect(!results.hadiths.isEmpty)
        #expect(results.hadiths.count <= SearchResultLimits.hadiths)
        #expect(hadithService.loadedCollectionCount == 0)
    }

    @Test func emptyQueryDoesNotStartHadithIndexing() async {
        let hadithService = HadithDataService()
        await hadithService.load()
        let snapshot = SearchContentSnapshot(
            quran: QuranSearchSnapshot(surahs: [], verses: []),
            hadithCollections: hadithService.searchCollectionsSnapshot(),
            duas: []
        )
        let index = SearchIndex()
        await index.configure(snapshot: snapshot)

        let results = await index.search(query: "   ")

        #expect(results.isEmpty)
        #expect(results.isHadithIndexing == false)
        #expect(await index.hadithIndexStateForTesting() == "notStarted")
    }

    @Test func matcherRanksExactPhraseAboveTokenMatch() {
        let query = SearchQuery("rely upon")
        let phraseScore = SearchTextMatcher.score(
            query: query,
            fields: [SearchField(text: "And rely upon Allah", normalized: SearchTextNormalizer.normalize("And rely upon Allah"), weight: 10)]
        )
        let tokenScore = SearchTextMatcher.score(
            query: query,
            fields: [SearchField(text: "Rely on Allah upon hardship", normalized: SearchTextNormalizer.normalize("Rely on Allah upon hardship"), weight: 10)]
        )

        #expect(phraseScore != nil)
        #expect(tokenScore != nil)
        #expect((phraseScore ?? 0) > (tokenScore ?? 0))
    }

    @Test func resultCapsAreEnforcedAcrossSections() async throws {
        let snapshot = await makeLoadedSnapshot()
        let index = SearchIndex()
        await index.configure(snapshot: snapshot)

        var results = await index.search(query: "the")
        for _ in 0..<60 where results.isHadithIndexing {
            try await Task.sleep(for: .milliseconds(100))
            results = await index.search(query: "the")
        }

        #expect(results.quranVerses.count <= SearchResultLimits.quranVerses)
        #expect(results.surahs.count <= SearchResultLimits.surahs)
        #expect(results.hadiths.count <= SearchResultLimits.hadiths)
        #expect(results.duas.count <= SearchResultLimits.duas)
    }

    private func makeLoadedSnapshot() async -> SearchContentSnapshot {
        let quranService = QuranDataService()
        await quranService.load()
        let hadithService = HadithDataService()
        await hadithService.load()
        let duaService = DuaDataService()
        await duaService.load()

        return SearchContentSnapshot(
            quran: quranService.searchSnapshot(script: .hafs),
            hadithCollections: hadithService.searchCollectionsSnapshot(),
            duas: duaService.searchSnapshot()
        )
    }
}
