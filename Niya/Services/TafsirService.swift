import Foundation

@Observable
@MainActor
final class TafsirService {
    @ObservationIgnored private var cache: [String: [String: String]] = [:]
    @ObservationIgnored private var accessOrder: [String] = []
    private let maxCachedSurahs = 10

    func text(edition: TafsirEdition, surahId: Int, ayahId: Int) -> String? {
        let key = "\(edition.rawValue):\(surahId)"
        if let dict = cache[key] {
            touchKey(key)
            return dict[String(ayahId)]
        }
        let dict = loadSurah(edition: edition, surahId: surahId)
        return dict[String(ayahId)]
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    private func loadSurah(edition: TafsirEdition, surahId: Int) -> [String: String] {
        let key = "\(edition.rawValue):\(surahId)"
        guard let url = Bundle.main.url(
            forResource: String(surahId),
            withExtension: "json",
            subdirectory: edition.bundleDirectory
        ),
        let data = try? Data(contentsOf: url),
        let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        cache[key] = dict
        touchKey(key)
        evictIfNeeded()
        return dict
    }

    private func touchKey(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictIfNeeded() {
        while cache.count > maxCachedSurahs {
            let oldest = accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }
}
