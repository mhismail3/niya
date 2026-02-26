import Foundation

@Observable
@MainActor
final class WordDataService {
    private(set) var isLoaded = false
    private var cache: [Int: [Int: VerseWordData]]?

    func load() async {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "word_data", withExtension: "json") else { return }
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
            isLoaded = true
        } catch {
            print("[WordDataService] Failed to load word data: \(error)")
        }
    }

    func words(surahId: Int, ayahId: Int) -> VerseWordData? {
        cache?[surahId]?[ayahId]
    }
}
