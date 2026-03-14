import Foundation

@Observable
@MainActor
final class WordDataService: WordDataProviding {
    private(set) var isLoaded = false
    private(set) var currentReciter: Reciter?
    private(set) var currentMeaningLanguage: String?
    private var cache: [Int: [Int: VerseWordData]]?
    private var meaningsOverlay: [String: String]?
    @ObservationIgnored private var overlaidCache: [Int: [Int: VerseWordData]] = [:]

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
            overlaidCache.removeAll()
            currentReciter = reciter
            isLoaded = true
        } catch {
            AppLogger.data.error("WordDataService load failed: \(error)")
        }
    }

    func loadMeanings(language: String) async {
        if !Self.supportedMeaningLanguages.contains(language) {
            meaningsOverlay = nil
            overlaidCache.removeAll()
            currentMeaningLanguage = nil
            return
        }
        if language == currentMeaningLanguage { return }

        let filename = "word_meanings_\(language)"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            meaningsOverlay = nil
            overlaidCache.removeAll()
            currentMeaningLanguage = nil
            return
        }
        do {
            let overlay = try await Task.detached {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([String: String].self, from: data)
            }.value
            meaningsOverlay = overlay
            overlaidCache.removeAll()
            currentMeaningLanguage = language
        } catch {
            AppLogger.data.error("WordDataService loadMeanings failed: \(error)")
            meaningsOverlay = nil
            overlaidCache.removeAll()
            currentMeaningLanguage = nil
        }
    }

    func words(surahId: Int, ayahId: Int) -> VerseWordData? {
        guard let data = cache?[surahId]?[ayahId] else { return nil }
        guard let overlay = meaningsOverlay else { return data }
        if let cached = overlaidCache[surahId]?[ayahId] { return cached }
        var words = data.w
        for i in words.indices {
            words[i].meaning = overlay["\(surahId):\(ayahId):\(words[i].p)"]
        }
        let result = VerseWordData(au: data.au, vs: data.vs, ve: data.ve, w: words)
        overlaidCache[surahId, default: [:]][ayahId] = result
        return result
    }

    func allVerseData(surahId: Int) -> [(ayahId: Int, data: VerseWordData)]? {
        guard let verses = cache?[surahId] else { return nil }
        guard let overlay = meaningsOverlay else {
            return verses.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
        }
        return verses.sorted(by: { $0.key < $1.key }).map { (ayahId, data) in
            if let cached = overlaidCache[surahId]?[ayahId] { return (ayahId, cached) }
            var words = data.w
            for i in words.indices {
                words[i].meaning = overlay["\(surahId):\(ayahId):\(words[i].p)"]
            }
            let result = VerseWordData(au: data.au, vs: data.vs, ve: data.ve, w: words)
            overlaidCache[surahId, default: [:]][ayahId] = result
            return (ayahId, result)
        }
    }
}
