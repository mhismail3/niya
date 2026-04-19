import CoreText
import Foundation
import UIKit

/// Immutable, shareable per-verse render inputs. Holds the shaped CTFramesetters and
/// attributed strings so TajweedRenderView instances don't redo that work on scroll-back-in.
final class TajweedPreparedContent {
    let text: String
    let baseAttributedString: NSAttributedString
    let baseFramesetter: CTFramesetter
    let overlayAttributedStrings: [TajweedRule: NSAttributedString]
    let overlayFramesetters: [TajweedRule: CTFramesetter]
    let resolvedSegments: [TajweedResolvedSegment]

    init(
        text: String,
        baseAttributedString: NSAttributedString,
        baseFramesetter: CTFramesetter,
        overlayAttributedStrings: [TajweedRule: NSAttributedString],
        overlayFramesetters: [TajweedRule: CTFramesetter],
        resolvedSegments: [TajweedResolvedSegment]
    ) {
        self.text = text
        self.baseAttributedString = baseAttributedString
        self.baseFramesetter = baseFramesetter
        self.overlayAttributedStrings = overlayAttributedStrings
        self.overlayFramesetters = overlayFramesetters
        self.resolvedSegments = resolvedSegments
    }
}

@Observable
@MainActor
final class TajweedService {
    @ObservationIgnored private var cache: [Int: [Int: TajweedVerse]]?
    private var isLoading = false

    @ObservationIgnored private let preparedCache: NSCache<NSString, TajweedPreparedContent> = {
        let c = NSCache<NSString, TajweedPreparedContent>()
        c.countLimit = 150
        return c
    }()

    func verse(surahId: Int, ayahId: Int) -> TajweedVerse? {
        cache?[surahId]?[ayahId]
    }

    func ensureLoaded() async {
        guard cache == nil, !isLoading else { return }
        isLoading = true
        do {
            let result = try await Task.detached {
                let data = try CompressedJSON.load(resource: "tajweed_hafs")
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
                return result
            }.value
            cache = result
        } catch {
            cache = [:]
        }
        isLoading = false
    }

    func clearCache() {
        cache = nil
        preparedCache.removeAllObjects()
    }

    /// Returns cached immutable render inputs for a verse. TajweedRenderView feeds these into
    /// its per-instance TextKit layouts. Keyed by (surahId, ayahId, fontSize, supplemental).
    /// Base text color is the dynamic `niyaText` asset — it resolves per trait collection at
    /// draw time, so we bake it into the cached AttributedString without keying on color.
    func preparedContent(
        verse: TajweedVerse,
        surahId: Int,
        fontSize: CGFloat,
        showSupplementalRules: Bool,
        paragraphStyle: NSParagraphStyle
    ) -> TajweedPreparedContent {
        let key = "\(surahId):\(verse.id):\(fontSize):\(showSupplementalRules)" as NSString
        if let hit = preparedCache.object(forKey: key) {
            return hit
        }

        let segments = TajweedTextResolver.resolveSegments(
            text: verse.text,
            annotations: verse.annotations,
            showSupplementalRules: showSupplementalRules
        )
        let font = UIFont.quranFont(script: .hafs, size: fontSize)
        let baseColor = UIColor(named: "niyaText") ?? .label
        let baseAttr = Self.makeAttributedString(
            text: verse.text, font: font, color: baseColor, paragraphStyle: paragraphStyle
        )
        let baseFramesetter = CTFramesetterCreateWithAttributedString(baseAttr)

        let visibleRules = Set(segments.map(\.rule))
        var overlayAttrs: [TajweedRule: NSAttributedString] = [:]
        var overlayFramesetters: [TajweedRule: CTFramesetter] = [:]
        overlayAttrs.reserveCapacity(visibleRules.count)
        overlayFramesetters.reserveCapacity(visibleRules.count)
        for rule in visibleRules {
            let attr = Self.makeAttributedString(
                text: verse.text, font: font, color: UIColor(rule.color), paragraphStyle: paragraphStyle
            )
            overlayAttrs[rule] = attr
            overlayFramesetters[rule] = CTFramesetterCreateWithAttributedString(attr)
        }

        let content = TajweedPreparedContent(
            text: verse.text,
            baseAttributedString: baseAttr,
            baseFramesetter: baseFramesetter,
            overlayAttributedStrings: overlayAttrs,
            overlayFramesetters: overlayFramesetters,
            resolvedSegments: segments
        )
        preparedCache.setObject(content, forKey: key)
        return content
    }

    private static func makeAttributedString(
        text: String, font: UIFont, color: UIColor, paragraphStyle: NSParagraphStyle
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ])
    }

    /// Normalize Arabic text with character substitutions for equivalent glyphs.
    /// No characters are stripped — fallback font handles unsupported marks.
    /// Result is cached per input string (verse text is immutable for the app lifetime).
    nonisolated static func cleanArabicText(_ input: String) -> String {
        let key = input as NSString
        if let cached = cleanedTextCache.object(forKey: key) {
            return cached as String
        }
        let cleaned = input
            .replacingOccurrences(of: "\u{06DF}", with: "\u{06E0}")  // Small High Rounded Zero → Upright Rectangular Zero
            .replacingOccurrences(of: "\u{0672}", with: "\u{0670}")  // Alef w/ Wavy Hamza → Superscript Alef
            .replacingOccurrences(of: "\u{066E}", with: "\u{0649}")  // Dotless Beh → Alef Maksura
        cleanedTextCache.setObject(cleaned as NSString, forKey: key)
        return cleaned
    }

    nonisolated static func clearCleanedTextCache() {
        cleanedTextCache.removeAllObjects()
    }

    nonisolated(unsafe) private static let cleanedTextCache: NSCache<NSString, NSString> = {
        let c = NSCache<NSString, NSString>()
        c.countLimit = 6500  // one per verse in the Quran
        return c
    }()
}
