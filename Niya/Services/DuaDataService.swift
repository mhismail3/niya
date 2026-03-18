import Foundation

@Observable
@MainActor
final class DuaDataService {
    var sections: [DuaSection] = []
    var categories: [DuaCategory] = []
    var isLoaded = false
    var loadError: String?

    private var duasByCategory: [String: [Dua]] = [:]
    private var categoryById: [String: DuaCategory] = [:]
    private var sectionById: [String: DuaSection] = [:]

    func load() async {
        guard !isLoaded else { return }
        loadError = nil
        do {
            guard let url = Bundle.main.url(forResource: "dua_all", withExtension: "json") else {
                throw DataError.missingResource("dua_all.json")
            }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(RawDuaFile.self, from: data)
            sections = decoded.sections
            categories = decoded.categories
            duasByCategory = decoded.duas
            categoryById = Dictionary(uniqueKeysWithValues: decoded.categories.map { ($0.id, $0) })
            sectionById = Dictionary(uniqueKeysWithValues: decoded.sections.map { ($0.id, $0) })
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    func categories(for sectionId: String) -> [DuaCategory] {
        guard let ids = sectionById[sectionId]?.categoryIds else { return [] }
        return ids.compactMap { categoryById[$0] }
    }

    func duas(for categoryId: String) -> [Dua] {
        duasByCategory[categoryId] ?? []
    }

    func dua(categoryId: String, duaId: String) -> Dua? {
        duasByCategory[categoryId]?.first { $0.id == duaId }
    }

    func category(id: String) -> DuaCategory? {
        categoryById[id]
    }

    func totalDuas(for sectionId: String) -> Int {
        categories(for: sectionId).reduce(0) { $0 + $1.totalDuas }
    }

    func searchDuas(query: String) -> [(categoryId: String, dua: Dua)] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var results: [(categoryId: String, dua: Dua)] = []
        for categoryId in duasByCategory.keys.sorted() {
            guard let duas = duasByCategory[categoryId] else { continue }
            for dua in duas {
                if results.count >= 50 { return results }
                let translation = dua.translation ?? ""
                if translation.range(of: q, options: .caseInsensitive) != nil ||
                   dua.arabic.contains(q) ||
                   (dua.transliteration?.range(of: q, options: .caseInsensitive) != nil) ||
                   (dua.context?.range(of: q, options: .caseInsensitive) != nil) {
                    results.append((categoryId, dua))
                }
            }
        }
        return results
    }
}

private struct RawDuaFile: Decodable {
    let sections: [DuaSection]
    let categories: [DuaCategory]
    let duas: [String: [Dua]]
}
