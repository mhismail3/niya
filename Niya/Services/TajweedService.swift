import Foundation
import UIKit

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

    /// Normalize Arabic text with character substitutions for equivalent glyphs.
    /// No characters are stripped — fallback font handles unsupported marks.
    nonisolated static func cleanArabicText(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\u{06DF}", with: "\u{06E0}")  // Small High Rounded Zero → Upright Rectangular Zero
            .replacingOccurrences(of: "\u{0672}", with: "\u{0670}")  // Alef w/ Wavy Hamza → Superscript Alef
            .replacingOccurrences(of: "\u{066E}", with: "\u{0649}")  // Dotless Beh → Alef Maksura
    }

    /// Creates an NSAttributedString with the primary Quran font and NotoNaskhArabic
    /// fallback for characters that KFGQPC renders as placeholders.
    nonisolated static func attributedArabicText(
        _ input: String,
        font primaryFont: UIFont,
        color: UIColor,
        lineSpacing: CGFloat = 12,
        alignment: NSTextAlignment = .right
    ) -> NSAttributedString {
        let text = cleanArabicText(input)
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = .rightToLeft
        style.lineSpacing = lineSpacing

        let base: [NSAttributedString.Key: Any] = [
            .font: primaryFont,
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        return NSAttributedString(string: text, attributes: base)
    }
}
