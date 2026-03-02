import Foundation

@Observable
@MainActor
final class TafsirService {
    private var cache: [String: TafsirEntry] = [:]
    private var loadingKeys: Set<String> = []
    private var failedKeys: [String: Date] = [:]
    private static let retryInterval: TimeInterval = 30

    func cacheKey(edition: TafsirEdition, surahId: Int, ayahId: Int) -> String {
        "\(edition.rawValue):\(surahId):\(ayahId)"
    }

    func entry(edition: TafsirEdition, surahId: Int, ayahId: Int) -> TafsirEntry? {
        cache[cacheKey(edition: edition, surahId: surahId, ayahId: ayahId)]
    }

    func isLoading(edition: TafsirEdition, surahId: Int, ayahId: Int) -> Bool {
        loadingKeys.contains(cacheKey(edition: edition, surahId: surahId, ayahId: ayahId))
    }

    func hasFailed(edition: TafsirEdition, surahId: Int, ayahId: Int) -> Bool {
        failedKeys[cacheKey(edition: edition, surahId: surahId, ayahId: ayahId)] != nil
    }

    func fetch(edition: TafsirEdition, surahId: Int, ayahId: Int) {
        let key = cacheKey(edition: edition, surahId: surahId, ayahId: ayahId)
        guard cache[key] == nil,
              !loadingKeys.contains(key),
              !isInCooldown(key) else { return }
        loadingKeys.insert(key)
        Task { await performFetch(edition: edition, surahId: surahId, ayahId: ayahId, key: key) }
    }

    func insertEntry(_ entry: TafsirEntry, edition: TafsirEdition, surahId: Int, ayahId: Int) {
        cache[cacheKey(edition: edition, surahId: surahId, ayahId: ayahId)] = entry
    }

    private func isInCooldown(_ key: String) -> Bool {
        guard let failedAt = failedKeys[key] else { return false }
        if Date().timeIntervalSince(failedAt) > Self.retryInterval {
            failedKeys.removeValue(forKey: key)
            return false
        }
        return true
    }

    private func performFetch(edition: TafsirEdition, surahId: Int, ayahId: Int, key: String) async {
        guard let url = edition.url(surahId: surahId, ayahId: ayahId) else {
            loadingKeys.remove(key)
            failedKeys[key] = Date()
            return
        }
        do {
            let decoded = try await NetworkClient.shared.fetch(TafsirEntry.self, from: url)
            cache[key] = decoded
            loadingKeys.remove(key)
        } catch {
            AppLogger.network.error("Tafsir fetch failed for \(key): \(error)")
            loadingKeys.remove(key)
            failedKeys[key] = Date()
        }
    }
}
