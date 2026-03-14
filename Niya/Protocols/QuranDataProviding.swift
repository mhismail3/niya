import Foundation

@MainActor protocol QuranDataProviding: AnyObject {
    var surahs: [Surah] { get }
    var isLoaded: Bool { get }
    var loadError: String? { get }
    var availableTranslations: [TranslationEdition] { get }
    var selectedTranslations: [TranslationEdition] { get }
    func load() async
    func verses(for surahId: Int, script: QuranScript) -> [Verse]
    func verse(surahId: Int, ayahId: Int) -> Verse?
    func pages(for surahId: Int, script: QuranScript) -> [[Verse]]
    func absoluteVerseNumber(surah: Int, ayah: Int) -> Int
    func surah(id: Int) -> Surah?
    func searchSurahs(query: String) -> [Surah]
    func addTranslation(_ edition: TranslationEdition) async throws
    func removeTranslation(_ edition: TranslationEdition)
    func isTranslationSelected(_ edition: TranslationEdition) -> Bool
}
