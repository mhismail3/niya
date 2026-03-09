import Foundation

@Observable
@MainActor
final class MorphologyService {
    @ObservationIgnored private var data: MorphologyData?

    func morphology(surahId: Int, ayahId: Int, position: Int) -> WordMorphology? {
        loadIfNeeded()
        let key = "\(surahId):\(ayahId):\(position)"
        return data?.words[key]
    }

    func rootEntry(_ root: String) -> RootEntry? {
        loadIfNeeded()
        return data?.roots[root]
    }

    func clearCache() {
        data = nil
    }

    private func loadIfNeeded() {
        guard data == nil else { return }
        guard let url = Bundle.main.url(forResource: "word_morphology", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(MorphologyData.self, from: raw) else {
            return
        }
        data = decoded
    }
}
