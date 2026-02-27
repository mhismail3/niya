import SwiftUI
import CoreText

struct WordView: View {
    let word: QuranWord
    let highlightState: WordHighlightState
    let showTransliteration: Bool
    let showMeaning: Bool
    let onTap: () -> Void
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                GlyphBoundsText(
                    text: word.t,
                    fontName: QuranScript.hafs.fontName,
                    fontSize: arabicFontSize,
                    color: UIColor(arabicColor),
                    isBold: highlightState == .current
                )

                if showTransliteration {
                    Text(word.tr)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(secondaryColor)
                }

                if showMeaning {
                    Text(word.en)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(secondaryColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                if highlightState == .current {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.niyaGold.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: highlightState)
    }

    private var arabicColor: Color {
        switch highlightState {
        case .current: .niyaGold
        case .completed: .niyaText.opacity(0.5)
        case .upcoming: .niyaText
        }
    }

    private var secondaryColor: Color {
        switch highlightState {
        case .current: .niyaGold.opacity(0.85)
        case .completed: .niyaSecondary.opacity(0.45)
        case .upcoming: .niyaSecondary
        }
    }
}

// MARK: - CoreText-based text view that sizes using actual glyph bounds

private struct GlyphBoundsText: UIViewRepresentable {
    let text: String
    let fontName: String
    let fontSize: Double
    let color: UIColor
    let isBold: Bool

    func makeUIView(context: Context) -> GlyphBoundsLabel {
        let label = GlyphBoundsLabel()
        label.backgroundColor = .clear
        label.isOpaque = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: GlyphBoundsLabel, context: Context) {
        label.textColor = color
        label.fontName = fontName
        label.fontSize = CGFloat(fontSize)
        label.isBold = isBold
        label.text = text
    }
}

private class GlyphBoundsLabel: UIView {
    var text: String = "" { didSet { rebuildLine() } }
    var fontName: String = "" { didSet { rebuildLine() } }
    var fontSize: CGFloat = 28 { didSet { rebuildLine() } }
    var textColor: UIColor = .label { didSet { setNeedsDisplay() } }
    var isBold: Bool = false { didSet { rebuildLine() } }

    private var line: CTLine?
    private var cachedGlyphBounds: CGRect = .zero
    private var cachedAdvanceWidth: CGFloat = 0
    private var cachedFontAscent: CGFloat = 0
    private var cachedFontDescent: CGFloat = 0

    private func rebuildLine() {
        guard !text.isEmpty else {
            line = nil
            cachedGlyphBounds = .zero
            cachedAdvanceWidth = 0
            cachedFontAscent = 0
            cachedFontDescent = 0
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
            return
        }
        var font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        if isBold,
           let bold = CTFontCreateCopyWithSymbolicTraits(font, fontSize, nil, .boldTrait, .boldTrait) {
            font = bold
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let ctLine = CTLineCreateWithAttributedString(attrStr)
        line = ctLine
        cachedGlyphBounds = CTLineGetBoundsWithOptions(ctLine, .useGlyphPathBounds)
        cachedAdvanceWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
        cachedFontAscent = CTFontGetAscent(font)
        cachedFontDescent = CTFontGetDescent(font)
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    override var intrinsicContentSize: CGSize {
        guard line != nil else { return .zero }
        return CGSize(
            width: ceil(max(cachedAdvanceWidth, cachedGlyphBounds.width)) + 2,
            height: ceil(cachedFontAscent + cachedFontDescent)
        )
    }

    override func draw(_ rect: CGRect) {
        guard let line, let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: rect.height)
        ctx.scaleBy(x: 1, y: -1)
        let gb = cachedGlyphBounds
        let x = (rect.width - gb.width) / 2 - gb.origin.x
        let y = cachedFontDescent
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
