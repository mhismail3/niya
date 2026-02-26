import Foundation

@Observable
@MainActor
final class DuaDataService {
    var sections: [DuaSection] = []
    var categories: [DuaCategory] = []
    var isLoaded = false
    var loadError: String?

    private var duasByCategory: [Int: [Dua]] = [:]

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
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    func categories(for sectionId: String) -> [DuaCategory] {
        let section = sections.first { $0.id == sectionId }
        guard let ids = section?.categoryIds else { return [] }
        return ids.compactMap { id in categories.first { $0.id == id } }
    }

    func duas(for categoryId: Int) -> [Dua] {
        duasByCategory[categoryId] ?? []
    }

    func dua(categoryId: Int, duaId: Int) -> Dua? {
        duasByCategory[categoryId]?.first { $0.id == duaId }
    }

    func category(id: Int) -> DuaCategory? {
        categories.first { $0.id == id }
    }

    func totalDuas(for sectionId: String) -> Int {
        categories(for: sectionId).reduce(0) { $0 + $1.totalDuas }
    }

    func searchDuas(query: String) -> [(categoryId: Int, dua: Dua)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var results: [(categoryId: Int, dua: Dua)] = []
        for categoryId in duasByCategory.keys.sorted() {
            guard let duas = duasByCategory[categoryId] else { continue }
            for dua in duas {
                if results.count >= 50 { return results }
                if dua.translation.lowercased().contains(q) ||
                   dua.arabic.contains(q) ||
                   (dua.transliteration?.lowercased().contains(q) ?? false) {
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
    let duas: [Int: [Dua]]

    enum CodingKeys: String, CodingKey {
        case sections, categories, duas
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sections = try container.decode([DuaSection].self, forKey: .sections)
        categories = try container.decode([DuaCategory].self, forKey: .categories)
        let stringKeyed = try container.decode([String: [Dua]].self, forKey: .duas)
        var intKeyed: [Int: [Dua]] = [:]
        for (key, value) in stringKeyed {
            if let intKey = Int(key) {
                intKeyed[intKey] = value
            }
        }
        duas = intKeyed
    }
}
