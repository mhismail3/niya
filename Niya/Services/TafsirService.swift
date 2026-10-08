import Foundation

@Observable
@MainActor
final class TafsirService {
    @ObservationIgnored private var cache: [String: [String: String]] = [:]
    @ObservationIgnored private var accessCounter: UInt64 = 0
    @ObservationIgnored private var accessTimes: [String: UInt64] = [:]
    @ObservationIgnored private var failedKeys: Set<String> = []
    private let maxCachedSurahs = 10

    func preload(edition: TafsirEdition, surahId: Int) async {
        let key = "\(edition.rawValue):\(surahId)"
        guard cache[key] == nil, !failedKeys.contains(key) else { return }
        do {
            let decoded = try await Task.detached {
                try CompressedJSON.decode([String: String].self, resource: String(surahId), subdirectory: edition.bundleDirectory)
            }.value
            cache[key] = decoded
            touchKey(key)
            evictIfNeeded()
        } catch {
            failedKeys.insert(key)
        }
    }

    func text(edition: TafsirEdition, surahId: Int, ayahId: Int) -> String? {
        let key = "\(edition.rawValue):\(surahId)"
        if let dict = cache[key] {
            touchKey(key)
            return dict[String(ayahId)]
        }
        guard !failedKeys.contains(key) else { return nil }
        do {
            let dict = try CompressedJSON.decode([String: String].self, resource: String(surahId), subdirectory: edition.bundleDirectory)
            cache[key] = dict
            touchKey(key)
            evictIfNeeded()
            return dict[String(ayahId)]
        } catch {
            failedKeys.insert(key)
            return nil
        }
    }

    func clearCache() {
        cache.removeAll()
        failedKeys.removeAll()
        accessTimes.removeAll()
        accessCounter = 0
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
