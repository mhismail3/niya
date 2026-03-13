import Foundation

@Observable
@MainActor
final class TajweedService {
    @ObservationIgnored private var cache: [Int: [Int: TajweedVerse]]?

    func verse(surahId: Int, ayahId: Int) -> TajweedVerse? {
        if cache == nil { loadFromBundle() }
        return cache?[surahId]?[ayahId]
    }

    func clearCache() {
        cache = nil
    }

    private func loadFromBundle() {
        guard let url = Bundle.main.url(forResource: "tajweed_hafs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            cache = [:]
            return
        }
        do {
            let raw = try JSONDecoder().decode([String: [TajweedVerse]].self, from: data)
            var result: [Int: [Int: TajweedVerse]] = [:]
            for (surahKey, verses) in raw {
                guard let surahId = Int(surahKey) else { continue }
                var surahDict: [Int: TajweedVerse] = [:]
                for verse in verses {
                    surahDict[verse.id] = verse
                }
                result[surahId] = surahDict
            }
            cache = result
        } catch {
            cache = [:]
        }
    }

    // MARK: - Unsupported Quran Marks

    nonisolated static let unsupportedQuranMarks: Set<UInt32> = [
        0x06DD, 0x06DE,                             // end-of-ayah, rub el hizb
        0x06E9,                                     // place of sajdah
        0x06EA, 0x06EB, 0x06EC,                     // small annotations
    ]
}
