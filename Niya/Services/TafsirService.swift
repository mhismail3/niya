import Foundation

@Observable
@MainActor
final class TafsirService {
    private var loaded: [TafsirEdition: [String: String]] = [:]

    func text(edition: TafsirEdition, surahId: Int, ayahId: Int) -> String? {
        let dict = loadEdition(edition)
        return dict["\(surahId):\(ayahId)"]
    }

    private func loadEdition(_ edition: TafsirEdition) -> [String: String] {
        if let existing = loaded[edition] { return existing }
        guard let url = Bundle.main.url(forResource: edition.bundleFilename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            loaded[edition] = [:]
            return [:]
        }
        loaded[edition] = dict
        return dict
    }
}
