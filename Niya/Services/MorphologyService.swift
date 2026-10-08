import Foundation

@Observable
@MainActor
final class MorphologyService {
    @ObservationIgnored private var data: MorphologyData?
    @ObservationIgnored private var meanings: [String: [RootMeaning]]?
    @ObservationIgnored private var hasAttemptedLoad = false
    @ObservationIgnored private var hasAttemptedMeaningsLoad = false

    @ObservationIgnored private var preloadTask: Task<Void, Never>?

    /// Decodes off the main thread. Concurrent callers (e.g. a sheet reopened mid-load)
    /// await the same load instead of seeing "attempted" before data exists.
    func preload() async {
        if let preloadTask { return await preloadTask.value }
        guard !hasAttemptedLoad || !hasAttemptedMeaningsLoad else { return }
        let task = Task {
            let decoded = try? await Task.detached {
                try CompressedJSON.decode(MorphologyData.self, resource: "word_morphology")
            }.value
            let decodedMeanings = try? await Task.detached {
                try CompressedJSON.decode([String: [RootMeaning]].self, resource: "root_meanings")
            }.value
            if !hasAttemptedLoad { data = decoded; hasAttemptedLoad = true }
            if !hasAttemptedMeaningsLoad { meanings = decodedMeanings; hasAttemptedMeaningsLoad = true }
        }
        preloadTask = task
        await task.value
        preloadTask = nil
    }

    func morphology(surahId: Int, ayahId: Int, position: Int) -> WordMorphology? {
        loadIfNeeded()
        let key = "\(surahId):\(ayahId):\(position)"
        return data?.words[key]
    }

    func rootEntry(_ root: String) -> RootEntry? {
        loadIfNeeded()
        return data?.roots[root]
    }

    func rootMeanings(_ root: String) -> [RootMeaning]? {
        loadMeaningsIfNeeded()
        return meanings?[root]
    }

    func clearCache() {
        data = nil
        meanings = nil
        hasAttemptedLoad = false
        hasAttemptedMeaningsLoad = false
    }

    private func loadIfNeeded() {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true
        data = try? CompressedJSON.decode(MorphologyData.self, resource: "word_morphology")
    }

    private func loadMeaningsIfNeeded() {
        guard !hasAttemptedMeaningsLoad else { return }
        hasAttemptedMeaningsLoad = true
        meanings = try? CompressedJSON.decode([String: [RootMeaning]].self, resource: "root_meanings")
    }
}
