import Foundation

@Observable
@MainActor
final class QuranDataService: QuranDataProviding {
    var surahs: [Surah] = []
    var isLoaded = false
    var loadError: String?
    var availableTranslations: [TranslationEdition] = []
    var selectedTranslations: [TranslationEdition] = []

    private var hafsDictionary: [String: [Verse]]?
    private var indoPakDictionary: [String: [Verse]]?
    private var verseCounts: [Int] = []
    private var translationOverlays: [(edition: TranslationEdition, overlay: [String: String])] = []
    private var versesCache: [String: [Verse]] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheEntries = 20

    func load() async {
        guard !isLoaded else { return }
        do {
            async let surahsTask = loadSurahs()
            async let hafsTask = loadVerses(filename: "verses_hafs")
            async let indoPakTask = loadVerses(filename: "verses_indopak")
            async let translationsTask = loadTranslationIndex()

            let (loadedSurahs, hafs, indoPak, translations) = try await (surahsTask, hafsTask, indoPakTask, translationsTask)
            surahs = loadedSurahs
            hafsDictionary = hafs
            indoPakDictionary = indoPak
            verseCounts = buildVerseCounts(from: loadedSurahs)
            availableTranslations = translations

            // Migrate from old single-translation key
            let savedRaw: String
            if let multi = UserDefaults.standard.string(forKey: StorageKey.selectedTranslations) {
                savedRaw = multi
            } else if let single = UserDefaults.standard.string(forKey: "selectedTranslation") {
                savedRaw = single
                UserDefaults.standard.removeObject(forKey: "selectedTranslation")
            } else {
                savedRaw = "en_sahih"
            }
            let savedIds = savedRaw.split(separator: ",").map(String.init)
            for id in savedIds {
                if let edition = translations.first(where: { $0.id == id }) {
                    try await addTranslation(edition)
                }
            }

            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    func verses(for surahId: Int, script: QuranScript) -> [Verse] {
        let translationIds = selectedTranslations.map(\.id).joined(separator: ",")
        let cacheKey = "\(surahId):\(script):\(translationIds)"
        if let cached = versesCache[cacheKey] { return cached }

        let dict = script == .hafs ? hafsDictionary : indoPakDictionary
        guard let baseVerses = dict?[String(surahId)] else { return [] }
        guard !translationOverlays.isEmpty else { return baseVerses }
        let primary = translationOverlays[0]
        let extras = Array(translationOverlays.dropFirst())
        let result = baseVerses.map { verse in
            let key = "\(surahId):\(verse.id)"
            let mainText = primary.overlay[key] ?? verse.translation
            var v = Verse(id: verse.id, text: verse.text, translation: mainText,
                          transliteration: verse.transliteration, page: verse.page)
            v.extraTranslations = extras.compactMap { entry in
                guard let text = entry.overlay[key] else { return nil }
                return TranslationText(name: entry.edition.name, text: text, isRTL: entry.edition.isRTL)
            }
            return v
        }
        versesCache[cacheKey] = result
        cacheOrder.removeAll { $0 == cacheKey }
        cacheOrder.append(cacheKey)
        while versesCache.count > maxCacheEntries, let oldest = cacheOrder.first {
            cacheOrder.removeFirst()
            versesCache.removeValue(forKey: oldest)
        }
        return result
    }

    func verse(surahId: Int, ayahId: Int) -> Verse? {
        verses(for: surahId, script: .hafs).first { $0.id == ayahId }
    }

    func pages(for surahId: Int, script: QuranScript) -> [[Verse]] {
        let all = verses(for: surahId, script: script)
        var grouped: [Int: [Verse]] = [:]
        for verse in all {
            grouped[verse.page, default: []].append(verse)
        }
        return grouped.keys.sorted().compactMap { grouped[$0] }
    }

    func absoluteVerseNumber(surah: Int, ayah: Int) -> Int {
        guard surah >= 1, surah <= verseCounts.count else { return ayah }
        let offset = verseCounts.prefix(surah - 1).reduce(0, +)
        return offset + ayah
    }

    func searchSurahs(query: String) -> [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return surahs }
        if let n = Int(q) {
            return surahs.filter { $0.id == n }
        }
        return surahs.filter {
            $0.transliteration.lowercased().contains(q) ||
            $0.translation.lowercased().contains(q) ||
            $0.name.contains(q)
        }
    }

    func addTranslation(_ edition: TranslationEdition) async throws {
        guard !selectedTranslations.contains(where: { $0.id == edition.id }) else { return }
        let name = edition.filename.replacingOccurrences(of: ".json", with: "")
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw DataError.missingResource(edition.filename)
        }
        let data = try Data(contentsOf: url)
        let overlay = try JSONDecoder().decode([String: String].self, from: data)
        translationOverlays.append((edition: edition, overlay: overlay))
        selectedTranslations.append(edition)
        versesCache.removeAll()
        saveSelectedIds()
    }

    func removeTranslation(_ edition: TranslationEdition) {
        translationOverlays.removeAll { $0.edition.id == edition.id }
        selectedTranslations.removeAll { $0.id == edition.id }
        versesCache.removeAll()
        saveSelectedIds()
    }

    func isTranslationSelected(_ edition: TranslationEdition) -> Bool {
        selectedTranslations.contains { $0.id == edition.id }
    }

    func clearCache() {
        versesCache.removeAll()
        cacheOrder.removeAll()
    }

    private func saveSelectedIds() {
        let ids = selectedTranslations.map(\.id).joined(separator: ",")
        UserDefaults.standard.set(ids, forKey: StorageKey.selectedTranslations)
        let hasRTL = selectedTranslations.contains { $0.isRTL }
        UserDefaults.standard.set(hasRTL, forKey: StorageKey.translationIsRTL)
    }

    private func loadTranslationIndex() async throws -> [TranslationEdition] {
        guard let url = Bundle.main.url(forResource: "translations_index", withExtension: "json") else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TranslationEdition].self, from: data)
    }

    private func loadSurahs() async throws -> [Surah] {
        guard let url = Bundle.main.url(forResource: "surahs", withExtension: "json") else {
            throw DataError.missingResource("surahs.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Surah].self, from: data)
    }

    private func loadVerses(filename: String) async throws -> [String: [Verse]] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw DataError.missingResource("\(filename).json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: [Verse]].self, from: data)
    }

    private func buildVerseCounts(from surahs: [Surah]) -> [Int] {
        surahs.sorted { $0.id < $1.id }.map(\.totalVerses)
    }
}

enum DataError: LocalizedError {
    case missingResource(String)
    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Missing bundle resource: \(name)"
        }
    }
}
