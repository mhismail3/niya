import Foundation

struct HadithCollectionData: Sendable {
    let chapters: [HadithChapter]
    let hadiths: [Hadith]
}

@Observable
@MainActor
final class HadithDataService {
    var collections: [HadithCollection] = []
    var isLoaded = false
    var loadError: String?

    private var loadedCollections: [String: HadithCollectionData] = [:]

    func load() async {
        guard !isLoaded else { return }
        loadError = nil
        do {
            guard let url = Bundle.main.url(forResource: "hadith_collections", withExtension: "json") else {
                throw DataError.missingResource("hadith_collections.json")
            }
            let data = try Data(contentsOf: url)
            collections = try JSONDecoder().decode([HadithCollection].self, from: data)
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    func isCollectionLoaded(_ id: String) -> Bool {
        loadedCollections[id] != nil
    }

    func loadCollection(_ id: String) async {
        guard loadedCollections[id] == nil else { return }
        guard let url = Bundle.main.url(forResource: "hadith_\(id)", withExtension: "json") else {
            loadError = "Missing resource: hadith_\(id).json"
            return
        }
        loadError = nil
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(RawCollectionFile.self, from: data)
            loadedCollections[id] = HadithCollectionData(
                chapters: decoded.chapters,
                hadiths: decoded.hadiths
            )
        } catch {
            loadError = "Failed to load \(id): \(error.localizedDescription)"
        }
    }

    func chapters(for collectionId: String) -> [HadithChapter] {
        loadedCollections[collectionId]?.chapters ?? []
    }

    func hadiths(for collectionId: String) -> [Hadith] {
        loadedCollections[collectionId]?.hadiths ?? []
    }

    func hadiths(for collectionId: String, chapterId: Int) -> [Hadith] {
        loadedCollections[collectionId]?.hadiths.filter { $0.chapterId == chapterId } ?? []
    }

    func searchHadiths(query: String) -> [(collectionId: String, hadith: Hadith)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var results: [(collectionId: String, hadith: Hadith)] = []
        for (collectionId, data) in loadedCollections {
            for hadith in data.hadiths {
                if results.count >= 50 { return results }
                if hadith.text.lowercased().contains(q) ||
                   hadith.narrator.lowercased().contains(q) ||
                   hadith.arabic.contains(q) {
                    results.append((collectionId, hadith))
                }
            }
        }
        return results
    }

    var loadedCollectionCount: Int {
        loadedCollections.count
    }
}

private struct RawCollectionFile: Decodable {
    let chapters: [HadithChapter]
    let hadiths: [Hadith]
}
