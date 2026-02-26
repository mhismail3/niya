import SwiftUI

@Observable
@MainActor
final class TajweedService {
    private var cache: [Int: [Int: TajweedVerse]] = [:]
    private var loadingSurahs: Set<Int> = []
    private var failedSurahs: [Int: Date] = [:]
    private static let retryInterval: TimeInterval = 30

    func verse(surahId: Int, ayahId: Int) -> TajweedVerse? {
        cache[surahId]?[ayahId]
    }

    func fetch(surahId: Int) {
        guard cache[surahId] == nil,
              !loadingSurahs.contains(surahId),
              !isInCooldown(surahId) else { return }
        loadingSurahs.insert(surahId)
        Task { await fetchSurah(surahId) }
    }

    private func isInCooldown(_ surahId: Int) -> Bool {
        guard let failedAt = failedSurahs[surahId] else { return false }
        if Date().timeIntervalSince(failedAt) > Self.retryInterval {
            failedSurahs.removeValue(forKey: surahId)
            return false
        }
        return true
    }

    private func fetchSurah(_ surahId: Int) async {
        let urlString = "https://api.qurani.ai/gw/qh/v1/surah/\(surahId)/quran-tajweed"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                loadingSurahs.remove(surahId)
                failedSurahs[surahId] = Date()
                return
            }
            let decoded = try JSONDecoder().decode(TajweedSurahResponse.self, from: data)
            var surahCache: [Int: TajweedVerse] = [:]
            for ayah in decoded.data.ayahs {
                let parsed = parseTajweedMarkup(ayah.text, ayahId: ayah.numberInSurah)
                surahCache[ayah.numberInSurah] = parsed
            }
            cache[surahId] = surahCache
        } catch {
            loadingSurahs.remove(surahId)
            failedSurahs[surahId] = Date()
        }
    }

    // MARK: - Markup Parser (operates on Unicode scalars to avoid grapheme cluster issues)

    private func parseTajweedMarkup(_ markup: String, ayahId: Int) -> TajweedVerse {
        let scalars = Array(markup.unicodeScalars)
        var plainText = ""
        var annotations: [TajweedAnnotation] = []
        var i = 0

        while i < scalars.count {
            if scalars[i] == Unicode.Scalar("[") {
                let afterBracket = i + 1
                guard afterBracket < scalars.count else {
                    plainText.append(String(scalars[i]))
                    i = afterBracket
                    continue
                }

                let tag = scalars[afterBracket]

                // Find the inner `[` that starts the annotated text
                var j = afterBracket + 1
                while j < scalars.count && scalars[j] != Unicode.Scalar("[") {
                    j += 1
                }
                guard j < scalars.count else {
                    plainText.append(String(String.UnicodeScalarView(scalars[i...])))
                    break
                }

                // j is at the inner `[`, read until `]`
                let textStart = j + 1
                var k = textStart
                while k < scalars.count && scalars[k] != Unicode.Scalar("]") {
                    k += 1
                }
                guard k < scalars.count else {
                    plainText.append(String(String.UnicodeScalarView(scalars[i...])))
                    break
                }

                let annotatedString = String(String.UnicodeScalarView(scalars[textStart..<k]))
                let start = plainText.count
                plainText.append(annotatedString)
                let end = plainText.count

                if let rule = TajweedRule(rawValue: String(tag)) {
                    annotations.append(TajweedAnnotation(rule: rule, start: start, end: end))
                }

                i = k + 1
            } else {
                plainText.append(String(scalars[i]))
                i += 1
            }
        }

        // Strip BOM if present
        if plainText.hasPrefix("\u{FEFF}") {
            let bomLen = 1
            plainText = String(plainText.dropFirst(bomLen))
            annotations = annotations.map {
                TajweedAnnotation(rule: $0.rule, start: $0.start - bomLen, end: $0.end - bomLen)
            }.filter { $0.start >= 0 }
        }

        return TajweedVerse(id: ayahId, text: plainText, annotations: annotations)
    }
}

// MARK: - API Response Types

private struct TajweedSurahResponse: Decodable {
    let data: SurahData

    struct SurahData: Decodable {
        let ayahs: [Ayah]
    }

    struct Ayah: Decodable {
        let numberInSurah: Int
        let text: String
    }
}
