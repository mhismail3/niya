import Foundation

struct QuranSearchSnapshot: Sendable {
    let surahs: [Surah]
    let verses: [QuranVerseSearchSource]
    let displayScript: QuranScript?

    init(surahs: [Surah], verses: [QuranVerseSearchSource], displayScript: QuranScript? = nil) {
        self.surahs = surahs
        self.verses = verses
        self.displayScript = displayScript
    }
}

struct QuranVerseSearchSource: Identifiable, Sendable {
    let id: String
    let surah: Surah
    let ayahId: Int
    let displayArabic: String
    let searchableArabic: [String]
    let displayTranslation: String
    let translationTexts: [TranslationText]

    init(
        surah: Surah,
        ayahId: Int,
        displayArabic: String,
        searchableArabic: [String],
        displayTranslation: String,
        translationTexts: [TranslationText]
    ) {
        self.id = "\(surah.id):\(ayahId)"
        self.surah = surah
        self.ayahId = ayahId
        self.displayArabic = displayArabic
        self.searchableArabic = searchableArabic
        self.displayTranslation = displayTranslation
        self.translationTexts = translationTexts
    }
}

@Observable
@MainActor
final class QuranDataService: QuranDataProviding {
    var surahs: [Surah] = [] {
        didSet { surahLookup = Dictionary(uniqueKeysWithValues: surahs.map { ($0.id, $0) }) }
    }
    var isLoaded = false
    var loadError: String?
    var availableTranslations: [TranslationEdition] = []
    var selectedTranslations: [TranslationEdition] = []

    private var hafsDictionary: [String: [Verse]]?
    private var indoPakDictionary: [String: [Verse]]?
    private var verseCounts: [Int] = []
    @ObservationIgnored private var surahLookup: [Int: Surah] = [:]
    private var translationOverlays: [(edition: TranslationEdition, overlay: [String: String])] = []
    @ObservationIgnored private var versesCache: [String: [Verse]] = [:]
    @ObservationIgnored private var cacheAccessCounter: UInt64 = 0
    @ObservationIgnored private var cacheAccessTimes: [String: UInt64] = [:]
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
            if let multi = UserDefaults.standard.string(forKey: StorageKey.selectedTranslations), !multi.isEmpty {
                savedRaw = multi
            } else if let single = UserDefaults.standard.string(forKey: StorageKey.selectedTranslationLegacy), !single.isEmpty {
                savedRaw = single
                UserDefaults.standard.removeObject(forKey: StorageKey.selectedTranslationLegacy)
            } else {
                savedRaw = "en_sahih"
            }
            var seenIds = Set<String>()
            let savedIds = savedRaw
                .split(separator: ",")
                .map(String.init)
                .filter { seenIds.insert($0).inserted }
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
        cacheAccessCounter += 1
        cacheAccessTimes[cacheKey] = cacheAccessCounter
        while versesCache.count > maxCacheEntries {
            guard let oldest = cacheAccessTimes.min(by: { $0.value < $1.value })?.key else { break }
            versesCache.removeValue(forKey: oldest)
            cacheAccessTimes.removeValue(forKey: oldest)
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

    func surah(id: Int) -> Surah? {
        surahLookup[id]
    }

    func searchSurahs(query: String) -> [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return surahs }
        if let n = Int(q) {
            return surahs.filter { $0.id == n }
        }
        return surahs.filter {
            $0.transliteration.range(of: q, options: .caseInsensitive) != nil ||
            $0.translation.range(of: q, options: .caseInsensitive) != nil ||
            $0.name.contains(q)
        }
    }

    func searchSnapshot(script: QuranScript) -> QuranSearchSnapshot {
        let displayDictionary = script == .hafs ? hafsDictionary : indoPakDictionary
        guard let displayDictionary else {
            return QuranSearchSnapshot(surahs: surahs, verses: [], displayScript: script)
        }

        var verseSources: [QuranVerseSearchSource] = []
        let sortedSurahs = surahs.sorted { $0.id < $1.id }
        for surah in sortedSurahs {
            let key = String(surah.id)
            guard let displayVerses = displayDictionary[key] else { continue }
            let hafsByAyah = Dictionary(uniqueKeysWithValues: (hafsDictionary?[key] ?? []).map { ($0.id, $0) })
            let indoPakByAyah = Dictionary(uniqueKeysWithValues: (indoPakDictionary?[key] ?? []).map { ($0.id, $0) })

            for verse in displayVerses {
                let overlayKey = "\(surah.id):\(verse.id)"
                let translationTexts = searchTranslationTexts(for: verse, key: overlayKey)
                let displayTranslation = translationTexts.first?.text ?? verse.translation
                var arabicTexts: [String] = [verse.text]
                if let hafs = hafsByAyah[verse.id]?.text {
                    arabicTexts.append(hafs)
                }
                if let indoPak = indoPakByAyah[verse.id]?.text {
                    arabicTexts.append(indoPak)
                }

                verseSources.append(
                    QuranVerseSearchSource(
                        surah: surah,
                        ayahId: verse.id,
                        displayArabic: verse.text,
                        searchableArabic: Array(Set(arabicTexts)),
                        displayTranslation: displayTranslation,
                        translationTexts: translationTexts
                    )
                )
            }
        }
        return QuranSearchSnapshot(surahs: sortedSurahs, verses: verseSources, displayScript: script)
    }

    func addTranslation(_ edition: TranslationEdition) async throws {
        if selectedTranslations.contains(where: { $0.id == edition.id }) { return }
        let name = edition.filename.replacingOccurrences(of: ".json", with: "")
        let overlay = try await Task.detached {
            try CompressedJSON.decode([String: String].self, resource: name)
        }.value
        // Re-check after await: a concurrent call may have added this edition while we were decoding.
        guard !selectedTranslations.contains(where: { $0.id == edition.id }) else { return }
        translationOverlays.append((edition: edition, overlay: overlay))
        selectedTranslations.append(edition)
        versesCache.removeAll()
        cacheAccessTimes.removeAll()
        cacheAccessCounter = 0
        saveSelectedIds()
    }

    func removeTranslation(_ edition: TranslationEdition) {
        translationOverlays.removeAll { $0.edition.id == edition.id }
        selectedTranslations.removeAll { $0.id == edition.id }
        versesCache.removeAll()
        cacheAccessTimes.removeAll()
        cacheAccessCounter = 0
        saveSelectedIds()
    }

    func isTranslationSelected(_ edition: TranslationEdition) -> Bool {
        selectedTranslations.contains { $0.id == edition.id }
    }

    func clearCache() {
        versesCache.removeAll()
        cacheAccessTimes.removeAll()
        cacheAccessCounter = 0
    }

    private func saveSelectedIds() {
        var seen = Set<String>()
        let ids = selectedTranslations
            .map(\.id)
            .filter { seen.insert($0).inserted }
            .joined(separator: ",")
        UserDefaults.standard.set(ids, forKey: StorageKey.selectedTranslations)
        let hasRTL = selectedTranslations.contains { $0.isRTL }
        UserDefaults.standard.set(hasRTL, forKey: StorageKey.translationIsRTL)
    }

    private func loadTranslationIndex() async throws -> [TranslationEdition] {
        try await Task.detached {
            try CompressedJSON.decode([TranslationEdition].self, resource: "translations_index")
        }.value
    }

    private func loadSurahs() async throws -> [Surah] {
        try await Task.detached {
            try CompressedJSON.decode([Surah].self, resource: "surahs")
        }.value
    }

    private func loadVerses(filename: String) async throws -> [String: [Verse]] {
        try await Task.detached {
            try CompressedJSON.decode([String: [Verse]].self, resource: filename)
        }.value
    }

    private func buildVerseCounts(from surahs: [Surah]) -> [Int] {
        surahs.sorted { $0.id < $1.id }.map(\.totalVerses)
    }

    private func searchTranslationTexts(for verse: Verse, key: String) -> [TranslationText] {
        guard !translationOverlays.isEmpty else {
            return [TranslationText(name: "Translation", text: verse.translation, isRTL: false)]
        }
        return translationOverlays.compactMap { entry in
            let text = entry.overlay[key] ?? verse.translation
            guard !text.isEmpty else { return nil }
            return TranslationText(name: entry.edition.name, text: text, isRTL: entry.edition.isRTL)
        }
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
