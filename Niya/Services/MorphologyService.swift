import Foundation

@Observable
@MainActor
final class MorphologyService {
    @ObservationIgnored private var data: MorphologyData?
    @ObservationIgnored private var meanings: [String: [RootMeaning]]?

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
    }

    private func loadIfNeeded() {
        guard data == nil else { return }
        guard let decoded = try? CompressedJSON.decode(MorphologyData.self, resource: "word_morphology") else {
            return
        }
        data = decoded
    }

    private func loadMeaningsIfNeeded() {
        guard meanings == nil else { return }
        guard let decoded = try? CompressedJSON.decode([String: [RootMeaning]].self, resource: "root_meanings") else {
            return
        }
        meanings = decoded
    }
}
