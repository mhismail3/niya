import SwiftUI

struct TajweedTap: Equatable {
    let rule: TajweedRule
    let position: CGPoint
}

private let tajweedRuleKey = NSAttributedString.Key("tajweedRule")

struct TajweedTextView: UIViewRepresentable {
    let verse: TajweedVerse
    let displayText: String
    let fontSize: CGFloat
    let onTap: (TajweedTap?) -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: false)
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0

        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tv.addGestureRecognizer(tap)

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        tv.attributedText = makeAttributedString()
        context.coordinator.onTap = onTap
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize, uiView: UITextView, context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.window?.screen.bounds.width ?? 390
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    private func makeAttributedString() -> NSAttributedString {
        let text = displayText
        let font = UIFont(name: QuranScript.hafs.fontName, size: fontSize)
            ?? .systemFont(ofSize: fontSize)
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        style.baseWritingDirection = .rightToLeft
        style.lineSpacing = 12

        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(named: "niyaText") ?? .label,
            .paragraphStyle: style,
        ]
        let result = NSMutableAttributedString(string: text, attributes: base)

        let mapped = Self.mapAnnotations(verse.annotations, from: verse.text, to: text)
        for ann in mapped {
            guard ann.start >= 0, ann.end <= text.count, ann.start < ann.end else { continue }
            let start = text.index(text.startIndex, offsetBy: ann.start)
            let end = text.index(text.startIndex, offsetBy: ann.end)
            let nsRange = NSRange(start..<end, in: text)
            result.addAttribute(.foregroundColor, value: UIColor(ann.rule.color), range: nsRange)
            result.addAttribute(tajweedRuleKey, value: ann.rule.rawValue, range: nsRange)
        }

        return result
    }

    /// Maps annotation positions from API-parsed text to the hafs display text
    /// by aligning base Arabic letters 1:1 between source and target.
    private static func mapAnnotations(
        _ annotations: [TajweedAnnotation],
        from source: String,
        to target: String
    ) -> [TajweedAnnotation] {
        guard !annotations.isEmpty else { return [] }
        if source == target { return annotations }

        let srcChars = Array(source)
        let tgtChars = Array(target)
        if srcChars.count == tgtChars.count { return annotations }

        var posMap = [Int](repeating: tgtChars.count, count: srcChars.count + 1)
        var ti = 0

        for si in 0..<srcChars.count {
            if let srcKey = alignmentKey(srcChars[si]) {
                let savedTi = ti
                var found = false
                var skippedLetters = 0
                while ti < tgtChars.count {
                    if let tgtKey = alignmentKey(tgtChars[ti]) {
                        if tgtKey == srcKey {
                            posMap[si] = ti
                            ti += 1
                            found = true
                            break
                        }
                        skippedLetters += 1
                        if skippedLetters > 2 { break }
                    }
                    ti += 1
                }
                if !found {
                    ti = savedTi
                    posMap[si] = min(ti, tgtChars.count)
                }
            } else {
                posMap[si] = min(ti, tgtChars.count)
            }
        }
        posMap[srcChars.count] = min(ti, tgtChars.count)

        return annotations.compactMap { ann in
            let s = ann.start < posMap.count ? posMap[ann.start] : tgtChars.count
            let e = ann.end < posMap.count ? posMap[ann.end] : tgtChars.count
            if s == e && s > 0 {
                return TajweedAnnotation(rule: ann.rule, start: s - 1, end: s)
            }
            guard s < e, e <= tgtChars.count else { return nil }
            return TajweedAnnotation(rule: ann.rule, start: s, end: e)
        }
    }

    /// Main Arabic letter of a grapheme cluster, excluding decorative Tatweel.
    /// Normalizes hamza carriers for cross-edition alignment (Tanzil vs Hafs).
    private static func alignmentKey(_ c: Character) -> UInt32? {
        if c == " " { return 0x0020 }
        for scalar in c.unicodeScalars {
            if scalar.properties.generalCategory == .otherLetter && scalar.value != 0x0640 {
                switch scalar.value {
                case 0x0623, 0x0625: return 0x0621 // alef+hamza above/below → hamza
                case 0x0649: return 0x064A // alef maksura → yeh
                default: return scalar.value
                }
            }
        }
        return nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onTap: (TajweedTap?) -> Void

        init(onTap: @escaping (TajweedTap?) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            let point = gesture.location(in: textView)
            let index = textView.layoutManager.characterIndex(
                for: point,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            guard index < textView.attributedText.length,
                  let raw = textView.attributedText.attribute(
                      tajweedRuleKey, at: index, effectiveRange: nil
                  ) as? String,
                  let rule = TajweedRule(rawValue: raw)
            else {
                onTap(nil)
                return
            }

            let charRange = NSRange(location: index, length: 1)
            let glyphRange = textView.layoutManager.glyphRange(
                forCharacterRange: charRange, actualCharacterRange: nil)
            let rect = textView.layoutManager.boundingRect(
                forGlyphRange: glyphRange, in: textView.textContainer)
            let position = CGPoint(x: rect.midX, y: rect.minY)

            onTap(TajweedTap(rule: rule, position: position))
        }
    }
}
