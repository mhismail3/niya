import Foundation

@Observable
@MainActor
final class MorphologyService {
    @ObservationIgnored private var data: MorphologyData?
    @ObservationIgnored private var meanings: [String: [RootMeaning]]?
    @ObservationIgnored private var hasAttemptedLoad = false
    @ObservationIgnored private var hasAttemptedMeaningsLoad = false

    func preload() async {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true
        data = try? await Task.detached {
            try CompressedJSON.decode(MorphologyData.self, resource: "word_morphology")
        }.value
        hasAttemptedMeaningsLoad = true
        meanings = try? await Task.detached {
            try CompressedJSON.decode([String: [RootMeaning]].self, resource: "root_meanings")
        }.value
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
