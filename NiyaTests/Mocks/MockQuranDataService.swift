import Foundation
@testable import Niya

@MainActor
final class MockQuranDataService: QuranDataProviding {
    var surahs: [Surah] = []
    var isLoaded = false
    var loadError: String?
    var availableTranslations: [TranslationEdition] = []
    var selectedTranslations: [TranslationEdition] = []

    var loadCallCount = 0
    var versesResult: [Verse] = []
    var pagesResult: [[Verse]] = []

    func load() async {
        loadCallCount += 1
        isLoaded = true
    }

    func verses(for surahId: Int, script: QuranScript) -> [Verse] {
        versesResult
    }

    func verse(surahId: Int, ayahId: Int) -> Verse? {
        versesResult.first { $0.id == ayahId }
    }

    func pages(for surahId: Int, script: QuranScript) -> [[Verse]] {
        pagesResult
    }

    func absoluteVerseNumber(surah: Int, ayah: Int) -> Int {
        ayah
    }

    func searchSurahs(query: String) -> [Surah] {
        surahs
    }

    func addTranslation(_ edition: TranslationEdition) async throws {}
    func removeTranslation(_ edition: TranslationEdition) {}

    func isTranslationSelected(_ edition: TranslationEdition) -> Bool {
        false
    }
}
