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
    @ObservationIgnored private var overlaidSurahOrder: [Int] = []
    private let maxOverlaidSurahs = 10

    nonisolated static let supportedMeaningLanguages: Set<String> = ["ur", "bn", "tr", "id", "fa", "hi", "ta"]

    func load(reciter: Reciter = .alAfasy) async {
        if isLoaded && currentReciter == reciter { return }
        let filename = reciter.wordDataFilename
        do {
            let result = try await Task.detached {
                let jsonData = try CompressedJSON.load(resource: filename)
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
            clearOverlaidCache()
            currentReciter = reciter
            isLoaded = true
        } catch {
            AppLogger.data.error("WordDataService load failed: \(error)")
        }
    }

    func loadMeanings(language: String) async {
        if !Self.supportedMeaningLanguages.contains(language) {
            meaningsOverlay = nil
            clearOverlaidCache()
            currentMeaningLanguage = nil
            return
        }
        if language == currentMeaningLanguage { return }

        let filename = "word_meanings_\(language)"
        do {
            let overlay = try await Task.detached {
                try CompressedJSON.decode([String: String].self, resource: filename)
            }.value
            meaningsOverlay = overlay
            clearOverlaidCache()
            currentMeaningLanguage = language
        } catch {
            AppLogger.data.error("WordDataService loadMeanings failed: \(error)")
            meaningsOverlay = nil
            clearOverlaidCache()
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
        trackOverlaidSurah(surahId)
        overlaidCache[surahId, default: [:]][ayahId] = result
        return result
    }

    func allVerseData(surahId: Int) -> [(ayahId: Int, data: VerseWordData)]? {
        guard let verses = cache?[surahId] else { return nil }
        guard let overlay = meaningsOverlay else {
            return verses.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
        }
        trackOverlaidSurah(surahId)
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

    func clearOverlaidCache() {
        overlaidCache.removeAll()
        overlaidSurahOrder.removeAll()
    }

    private func trackOverlaidSurah(_ surahId: Int) {
        if overlaidCache[surahId] != nil {
            // Already tracked, move to end
            if let idx = overlaidSurahOrder.firstIndex(of: surahId) {
                overlaidSurahOrder.remove(at: idx)
            }
            overlaidSurahOrder.append(surahId)
            return
        }
        overlaidSurahOrder.append(surahId)
        while overlaidSurahOrder.count > maxOverlaidSurahs {
            let evicted = overlaidSurahOrder.removeFirst()
            overlaidCache.removeValue(forKey: evicted)
        }
    }
}
