import SwiftUI
import UIKit

extension Font {
    static func quranText(script: QuranScript, size: CGFloat? = nil) -> Font {
        let s = size ?? script.fontSize
        return Font(UIFont.quranFont(script: script, size: s))
    }

    static let niyaTitle = Font.system(.title2, design: .serif, weight: .medium)
    static let niyaHeadline = Font.system(.headline, design: .serif)
    static let niyaBody = Font.system(.body, design: .serif, weight: .medium)
    static let niyaSubheadline = Font.system(.subheadline, design: .serif, weight: .medium)
    static let niyaCaption = Font.system(.caption, design: .serif, weight: .regular)
    static let niyaCaption2 = Font.system(.caption2, design: .serif, weight: .regular)
    static let niyaVerseAction = Font.title3
}

extension UIFont {
    nonisolated(unsafe) private static let quranFontCache: NSCache<NSString, UIFont> = {
        let c = NSCache<NSString, UIFont>()
        c.countLimit = 16
        return c
    }()

    /// Creates a Quran font with NotoNaskhArabic as cascade fallback for marks
    /// the primary Uthmanic font cannot render (e.g. U+06ED small low meem).
    static func quranFont(script: QuranScript, size: CGFloat) -> UIFont {
        let key = "\(script.fontName):\(size)" as NSString
        if let cached = quranFontCache.object(forKey: key) {
            return cached
        }
        guard let base = UIFont(name: script.fontName, size: size) else {
            return .systemFont(ofSize: size)
        }
        let fallbackDesc = UIFontDescriptor(name: "NotoNaskhArabic", size: size)
        let cascadeDesc = base.fontDescriptor.addingAttributes([
            .cascadeList: [fallbackDesc]
        ])
        let font = UIFont(descriptor: cascadeDesc, size: size)
        quranFontCache.setObject(font, forKey: key)
        return font
    }

    static func clearQuranFontCache() {
        quranFontCache.removeAllObjects()
    }
}
