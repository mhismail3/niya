import SwiftUI

extension Font {
    static func quranText(script: QuranScript, size: CGFloat? = nil) -> Font {
        .custom(script.fontName, size: size ?? script.fontSize)
    }

    static let niyaTitle = Font.system(.title2, design: .serif, weight: .medium)
    static let niyaHeadline = Font.system(.headline, design: .serif)
    static let niyaBody = Font.system(.body, design: .serif, weight: .medium)
    static let niyaSubheadline = Font.system(.subheadline, design: .serif, weight: .medium)
    static let niyaCaption = Font.system(.caption, design: .serif, weight: .regular)
    static let niyaCaption2 = Font.system(.caption2, design: .serif, weight: .regular)
    static let niyaVerseAction = Font.title3
}
