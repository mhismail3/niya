import Foundation

@Observable
@MainActor
final class TafsirService {
    @ObservationIgnored private var cache: [String: [String: String]] = [:]
    @ObservationIgnored private var accessCounter: UInt64 = 0
    @ObservationIgnored private var accessTimes: [String: UInt64] = [:]
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
        accessTimes.removeAll()
        accessCounter = 0
    }

    private func loadSurah(edition: TafsirEdition, surahId: Int) -> [String: String] {
        let key = "\(edition.rawValue):\(surahId)"
        guard let dict = try? CompressedJSON.decode(
            [String: String].self,
            resource: String(surahId),
            subdirectory: edition.bundleDirectory
        ) else {
            return [:]
        }
        cache[key] = dict
        touchKey(key)
        evictIfNeeded()
        return dict
    }

    private func touchKey(_ key: String) {
        accessCounter += 1
        accessTimes[key] = accessCounter
    }

    private func evictIfNeeded() {
        while cache.count > maxCachedSurahs {
            guard let oldest = accessTimes.min(by: { $0.value < $1.value })?.key else { break }
            cache.removeValue(forKey: oldest)
            accessTimes.removeValue(forKey: oldest)
        }
    }
}
