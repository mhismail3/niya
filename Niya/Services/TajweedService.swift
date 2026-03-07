import SwiftUI

@Observable
@MainActor
final class TajweedService {
    var lastError: AppError?
    private var cache: [Int: [Int: TajweedVerse]] = [:]
    private var loadingSurahs: Set<Int> = []
    private var failedSurahs: [Int: Date] = [:]
    private var activeTasks: [Int: Task<Void, Never>] = [:]
    private static let retryInterval: TimeInterval = 30

    func verse(surahId: Int, ayahId: Int) -> TajweedVerse? {
        cache[surahId]?[ayahId]
    }

    func fetch(surahId: Int) {
        guard cache[surahId] == nil,
              !loadingSurahs.contains(surahId),
              !isInCooldown(surahId) else { return }
        loadingSurahs.insert(surahId)
        activeTasks[surahId] = Task { await fetchSurah(surahId) }
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
            let (data, _) = try await NetworkClient.shared.fetchRaw(from: url)
            let decoded = try JSONDecoder().decode(TajweedSurahResponse.self, from: data)
            var surahCache: [Int: TajweedVerse] = [:]
            for ayah in decoded.data.ayahs {
                let parsed = parseTajweedMarkup(ayah.text, ayahId: ayah.numberInSurah)
                surahCache[ayah.numberInSurah] = parsed
            }
            cache[surahId] = surahCache
            loadingSurahs.remove(surahId)
            activeTasks.removeValue(forKey: surahId)
        } catch {
            AppLogger.network.error("Tajweed fetch failed for surah \(surahId): \(error)")
            loadingSurahs.remove(surahId)
            activeTasks.removeValue(forKey: surahId)
            failedSurahs[surahId] = Date()
            lastError = .network("Could not load tajweed data. Check your connection.")
            Task {
                try? await Task.sleep(for: .seconds(5))
                self.lastError = nil
            }
        }
    }

    func clearCache() {
        for task in activeTasks.values { task.cancel() }
        activeTasks.removeAll()
        cache.removeAll()
        failedSurahs.removeAll()
    }

    // MARK: - Unsupported Quran Marks

    nonisolated static let unsupportedQuranMarks: Set<UInt32> = [
        0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DC, // waqf signs
        0x06DD, 0x06DE,                                             // end-of-ayah, rub el hizb
        0x06E9,                                                     // place of sajdah
        0x06EA, 0x06EB, 0x06EC, 0x06ED,                            // small annotations
    ]

    // MARK: - Markup Parser (recursive descent, operates on Unicode scalars)

    func parseTajweedMarkup(_ markup: String, ayahId: Int) -> TajweedVerse {
        let scalars = Array(markup.unicodeScalars)
        var plainText = ""
        var annotations: [TajweedAnnotation] = []

        _ = Self.parseContent(scalars, from: 0, into: &plainText, annotations: &annotations, untilClose: false)

        // Strip BOM if present
        if plainText.hasPrefix("\u{FEFF}") {
            let bomLen = 1
            plainText = String(plainText.dropFirst(bomLen))
            annotations = annotations.map {
                TajweedAnnotation(rule: $0.rule, start: $0.start - bomLen, end: $0.end - bomLen)
            }.filter { $0.start >= 0 }
        }

        // Normalize characters the API uses that the KFGQPC Uthmanic font lacks glyphs for.
        plainText = plainText
            .replacingOccurrences(of: "\u{0672}", with: "\u{0670}")  // Alef w/ Wavy Hamza → Superscript Alef
            .replacingOccurrences(of: "\u{06DF}", with: "\u{06E0}")  // Small High Rounded Zero → Upright Rectangular Zero
            .replacingOccurrences(of: "\u{066E}", with: "\u{0649}")  // Dotless Beh → Alef Maksura

        return TajweedVerse(id: ayahId, text: plainText, annotations: annotations)
    }

    /// Recursive descent parser for tajweed markup.
    /// Returns the index after the last consumed scalar.
    /// When `untilClose` is true, stops at the matching `]` and consumes it.
    nonisolated private static func parseContent(
        _ scalars: [Unicode.Scalar],
        from startIndex: Int,
        into plainText: inout String,
        annotations: inout [TajweedAnnotation],
        untilClose: Bool
    ) -> Int {
        var i = startIndex
        let open = Unicode.Scalar("[")
        let close = Unicode.Scalar("]")

        while i < scalars.count {
            let scalar = scalars[i]

            if scalar == close && untilClose {
                return i + 1 // consume the closer
            }

            if scalar == open {
                // Try to parse a tag: [TAG[...] or [TAG:N[...]
                let afterBracket = i + 1
                guard afterBracket < scalars.count else {
                    plainText.unicodeScalars.append(scalar)
                    i = afterBracket
                    continue
                }

                let tag = scalars[afterBracket]

                // Scan forward for the inner `[` (skipping optional `:N` modifier)
                var j = afterBracket + 1
                while j < scalars.count && scalars[j] != open && scalars[j] != close {
                    j += 1
                }

                if j < scalars.count && scalars[j] == open {
                    // Valid tag opener found — recurse into the tag body
                    let textStart = plainText.count
                    i = parseContent(scalars, from: j + 1, into: &plainText, annotations: &annotations, untilClose: true)
                    let textEnd = plainText.count

                    if let rule = TajweedRule(rawValue: String(tag)) {
                        annotations.append(TajweedAnnotation(rule: rule, start: textStart, end: textEnd))
                    }
                } else {
                    // Malformed — no inner `[` found, dump `[` as literal
                    plainText.unicodeScalars.append(scalar)
                    i += 1
                }
            } else if unsupportedQuranMarks.contains(scalar.value) {
                i += 1 // skip unsupported mark
            } else {
                plainText.unicodeScalars.append(scalar)
                i += 1
            }
        }

        return scalars.count
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
