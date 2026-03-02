import Foundation

@Observable
@MainActor
final class WordDataService {
    private(set) var isLoaded = false
    private(set) var currentReciter: Reciter?
    private var cache: [Int: [Int: VerseWordData]]?

    func load(reciter: Reciter = .alAfasy) async {
        if isLoaded && currentReciter == reciter { return }
        let filename = reciter.wordDataFilename
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([String: [String: VerseWordData]].self, from: data)
            var result: [Int: [Int: VerseWordData]] = [:]
            for (surahKey, verses) in raw {
                guard let surahId = Int(surahKey) else { continue }
                var verseMap: [Int: VerseWordData] = [:]
                for (verseKey, wordData) in verses {
                    guard let verseId = Int(verseKey) else { continue }
                    verseMap[verseId] = wordData
                }
                result[surahId] = verseMap
            }
            cache = result
            currentReciter = reciter
            isLoaded = true
        } catch {
            AppLogger.data.error("WordDataService load failed: \(error)")
        }
    }

    func words(surahId: Int, ayahId: Int) -> VerseWordData? {
        cache?[surahId]?[ayahId]
    }

    func allVerseData(surahId: Int) -> [(ayahId: Int, data: VerseWordData)]? {
        guard let verses = cache?[surahId] else { return nil }
        return verses.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
    }
}
