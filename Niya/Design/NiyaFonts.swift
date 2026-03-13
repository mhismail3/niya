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
    /// Creates a Quran font with NotoNaskhArabic as cascade fallback for marks
    /// the primary Uthmanic font cannot render (e.g. U+06ED small low meem).
    static func quranFont(script: QuranScript, size: CGFloat) -> UIFont {
        guard let base = UIFont(name: script.fontName, size: size) else {
            return .systemFont(ofSize: size)
        }
        let fallbackDesc = UIFontDescriptor(name: "NotoNaskhArabic", size: size)
        let cascadeDesc = base.fontDescriptor.addingAttributes([
            .cascadeList: [fallbackDesc]
        ])
        return UIFont(descriptor: cascadeDesc, size: size)
    }
}
