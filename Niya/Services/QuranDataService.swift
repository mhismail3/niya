import Foundation

@Observable
@MainActor
final class QuranDataService {
    var surahs: [Surah] = []
    var isLoaded = false
    var loadError: String?
    var availableTranslations: [TranslationEdition] = []
    var selectedTranslation: TranslationEdition?

    private var hafsDictionary: [String: [Verse]]?
    private var indoPakDictionary: [String: [Verse]]?
    private var verseCounts: [Int] = []
    private var translationOverlay: [String: String]?

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

            let savedId = UserDefaults.standard.string(forKey: "selectedTranslation") ?? "en_sahih"
            if let edition = translations.first(where: { $0.id == savedId }) {
                try await loadTranslation(edition)
            }

            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    func verses(for surahId: Int, script: QuranScript) -> [Verse] {
        let dict = script == .hafs ? hafsDictionary : indoPakDictionary
        guard let baseVerses = dict?[String(surahId)] else { return [] }
        guard let overlay = translationOverlay else { return baseVerses }
        return baseVerses.map { verse in
            let key = "\(surahId):\(verse.id)"
            guard let translated = overlay[key] else { return verse }
            return Verse(id: verse.id, text: verse.text, translation: translated,
                         transliteration: verse.transliteration, page: verse.page)
        }
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
        return grouped.keys.sorted().map { grouped[$0]! }
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

    func loadTranslation(_ edition: TranslationEdition) async throws {
        let name = edition.filename.replacingOccurrences(of: ".json", with: "")
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw DataError.missingResource(edition.filename)
        }
        let data = try Data(contentsOf: url)
        translationOverlay = try JSONDecoder().decode([String: String].self, from: data)
        selectedTranslation = edition
        UserDefaults.standard.set(edition.id, forKey: "selectedTranslation")
        UserDefaults.standard.set(edition.isRTL, forKey: "translationIsRTL")
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
