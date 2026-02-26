import SwiftUI

struct TajweedTap: Equatable {
    let rule: TajweedRule
    let position: CGPoint
}

private let tajweedRuleKey = NSAttributedString.Key("tajweedRule")

struct TajweedTextView: UIViewRepresentable {
    let verse: TajweedVerse
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
        let text = verse.text
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

        for ann in verse.annotations {
            guard ann.start >= 0, ann.end <= text.count, ann.start < ann.end else { continue }
            let start = text.index(text.startIndex, offsetBy: ann.start)
            let end = text.index(text.startIndex, offsetBy: ann.end)
            let nsRange = NSRange(start..<end, in: text)
            result.addAttribute(.foregroundColor, value: UIColor(ann.rule.color), range: nsRange)
            result.addAttribute(tajweedRuleKey, value: ann.rule.rawValue, range: nsRange)
        }
        return result
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
