import Foundation

@Observable
@MainActor
final class WordDataService: WordDataProviding {
    private(set) var isLoaded = false
    private(set) var currentReciter: Reciter?
    private(set) var currentMeaningLanguage: String?
    private var cache: [Int: [Int: VerseWordData]]?
    private var meaningsOverlay: [String: String]?

    nonisolated static let supportedMeaningLanguages: Set<String> = ["ur", "bn", "tr", "id", "fa", "hi", "ta"]

    func load(reciter: Reciter = .alAfasy) async {
        if isLoaded && currentReciter == reciter { return }
        let filename = reciter.wordDataFilename
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else { return }
        do {
            let jsonData = try Data(contentsOf: url)
            let result = try await Task.detached {
                let raw = try JSONDecoder().decode([String: [String: VerseWordData]].self, from: jsonData)
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
                return result
            }.value
            cache = result
            currentReciter = reciter
            isLoaded = true
            if currentMeaningLanguage != nil {
                applyMeaningsOverlay()
            }
        } catch {
            AppLogger.data.error("WordDataService load failed: \(error)")
        }
    }

    func loadMeanings(language: String) async {
        if !Self.supportedMeaningLanguages.contains(language) {
            clearMeanings()
            return
        }
        if language == currentMeaningLanguage { return }

        let filename = "word_meanings_\(language)"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            clearMeanings()
            return
        }
        do {
            let overlay = try await Task.detached {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([String: String].self, from: data)
            }.value
            meaningsOverlay = overlay
            currentMeaningLanguage = language
            applyMeaningsOverlay()
        } catch {
            AppLogger.data.error("WordDataService loadMeanings failed: \(error)")
            clearMeanings()
        }
    }

    func words(surahId: Int, ayahId: Int) -> VerseWordData? {
        cache?[surahId]?[ayahId]
    }

    func allVerseData(surahId: Int) -> [(ayahId: Int, data: VerseWordData)]? {
        guard let verses = cache?[surahId] else { return nil }
        return verses.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
    }

    private func clearMeanings() {
        guard currentMeaningLanguage != nil else { return }
        meaningsOverlay = nil
        currentMeaningLanguage = nil
        guard var cache else { return }
        for (surahId, verses) in cache {
            for (verseId, verseData) in verses {
                var words = verseData.w
                for i in words.indices {
                    words[i].meaning = nil
                }
                cache[surahId]?[verseId] = VerseWordData(au: verseData.au, vs: verseData.vs, ve: verseData.ve, w: words)
            }
        }
        self.cache = cache
    }

    private func applyMeaningsOverlay() {
        guard let overlay = meaningsOverlay, var cache else { return }
        for (surahId, verses) in cache {
            for (verseId, verseData) in verses {
                var words = verseData.w
                for i in words.indices {
                    let key = "\(surahId):\(verseId):\(words[i].p)"
                    words[i].meaning = overlay[key]
                }
                cache[surahId]?[verseId] = VerseWordData(au: verseData.au, vs: verseData.vs, ve: verseData.ve, w: words)
            }
        }
        self.cache = cache
    }
}
