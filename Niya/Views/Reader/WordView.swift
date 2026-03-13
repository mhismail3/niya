import SwiftUI
import CoreText

struct WordView: View {
    let word: QuranWord
    let highlightState: WordHighlightState
    let showTransliteration: Bool
    let showMeaning: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    @AppStorage(StorageKey.arabicFontSize) private var arabicFontSize: Double = 28
    @AppStorage(StorageKey.followAlongTransliterationFontSize) private var transliterationSize: Double = 12
    @AppStorage(StorageKey.followAlongMeaningFontSize) private var meaningSize: Double = 11
    @State private var isPressing = false

    var body: some View {
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
                    .font(.system(size: transliterationSize, design: .serif))
                    .foregroundStyle(secondaryColor)
                    .accessibilityLabel("Transliteration: \(word.tr)")
            }

            if showMeaning {
                Text(word.displayMeaning)
                    .font(.system(size: meaningSize, design: .serif))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Meaning: \(word.displayMeaning)")
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
        .scaleEffect(isPressing ? 0.92 : 1.0)
        .opacity(isPressing ? 0.7 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress()
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressing = pressing
            }
        }
        .accessibilityAction(named: "Word Details") { onLongPress() }
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
        let cleaned = Self.textWithSupportedGlyphs(text, font: font)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let attrStr = NSAttributedString(string: cleaned, attributes: attrs)
        let ctLine = CTLineCreateWithAttributedString(attrStr)
        line = ctLine
        cachedGlyphBounds = CTLineGetBoundsWithOptions(ctLine, .useGlyphPathBounds)
        cachedAdvanceWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
        cachedFontAscent = CTFontGetAscent(font)
        cachedFontDescent = CTFontGetDescent(font)
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    /// Replaces characters the font lacks glyphs for with equivalents, then strips any remaining unsupported characters.
    private static func textWithSupportedGlyphs(_ input: String, font: CTFont) -> String {
        // Apply known substitutions (characters with equivalent glyphs in Uthmanic fonts)
        let text = input
            .replacingOccurrences(of: "\u{06DF}", with: "\u{06E0}")  // Small High Rounded Zero → Upright Rectangular Zero
            .replacingOccurrences(of: "\u{0672}", with: "\u{0670}")  // Alef w/ Wavy Hamza → Superscript Alef
            .replacingOccurrences(of: "\u{066E}", with: "\u{0649}")  // Dotless Beh → Alef Maksura

        // Quranic annotation marks without font glyph support.
        // U+06DD-U+06DE: end-of-ayah/section marks,
        // U+06E9: place of sajdah, U+06EA-U+06EC: small annotations
        let stripSet: Set<UInt32> = [
            0x06DD, 0x06DE,
            0x06E9,
            0x06EA, 0x06EB, 0x06EC,
        ]

        let scalars = Array(text.unicodeScalars)
        guard !scalars.isEmpty else { return text }

        var hasUnsupported = false
        var supported = [Bool](repeating: true, count: scalars.count)
        for (i, scalar) in scalars.enumerated() {
            if stripSet.contains(scalar.value) {
                supported[i] = false
                hasUnsupported = true
                continue
            }
            guard scalar.value <= 0xFFFF else { continue }
            var utf16 = UniChar(truncatingIfNeeded: scalar.value)
            var glyph: CGGlyph = 0
            if !CTFontGetGlyphsForCharacters(font, &utf16, &glyph, 1) {
                supported[i] = false
                hasUnsupported = true
            }
        }
        guard hasUnsupported else { return text }

        var result = String.UnicodeScalarView()
        result.reserveCapacity(scalars.count)
        for (i, scalar) in scalars.enumerated() where supported[i] {
            result.append(scalar)
        }
        return String(result)
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
