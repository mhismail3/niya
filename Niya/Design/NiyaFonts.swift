import SwiftUI

extension Font {
    static func quranText(script: QuranScript, size: CGFloat? = nil) -> Font {
        .custom(script.fontName, size: size ?? script.fontSize)
    }

    static let niyaTitle = Font.system(.title2, design: .serif, weight: .medium)
    static let niyaCaption = Font.system(.caption, design: .default, weight: .regular)
}
