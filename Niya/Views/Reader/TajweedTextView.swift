import CoreText
import SwiftUI
import UIKit

let tajweedMeasurementHeight: CGFloat = 10_000

struct TajweedTap: Equatable {
    let rule: TajweedRule
    let position: CGPoint
}

struct TajweedResolvedSegment: Equatable {
    let rule: TajweedRule
    let start: Int
    let end: Int
    let utf16Range: NSRange

    func contains(utf16Index: Int) -> Bool {
        NSLocationInRange(utf16Index, utf16Range)
    }
}

enum TajweedTextResolver {
    static func resolveSegments(
        text: String,
        annotations: [TajweedAnnotation],
        showSupplementalRules: Bool
    ) -> [TajweedResolvedSegment] {
        guard !text.isEmpty else { return [] }

        var resolvedRules = [TajweedRule?](repeating: nil, count: text.count)
        for annotation in annotations {
            guard annotation.rule.isVisible(showSupplementalRules: showSupplementalRules),
                  annotation.start >= 0,
                  annotation.end <= text.count,
                  annotation.start < annotation.end
            else {
                continue
            }

            for index in annotation.start..<annotation.end {
                resolvedRules[index] = annotation.rule
            }
        }

        var segments: [TajweedResolvedSegment] = []
        var currentRule: TajweedRule?
        var currentStart: Int?

        for (index, rule) in resolvedRules.enumerated() {
            switch (currentRule, rule) {
            case let (activeRule?, nextRule?) where activeRule == nextRule:
                continue
            case let (activeRule?, nextRule):
                if let start = currentStart,
                   let utf16Range = utf16Range(in: text, start: start, end: index) {
                    segments.append(TajweedResolvedSegment(
                        rule: activeRule,
                        start: start,
                        end: index,
                        utf16Range: utf16Range
                    ))
                }
                currentRule = nextRule
                currentStart = nextRule == nil ? nil : index
            case (nil, let nextRule?):
                currentRule = nextRule
                currentStart = index
            case (nil, nil):
                continue
            }
        }

        if let activeRule = currentRule,
           let start = currentStart,
           let utf16Range = utf16Range(in: text, start: start, end: text.count) {
            segments.append(TajweedResolvedSegment(
                rule: activeRule,
                start: start,
                end: text.count,
                utf16Range: utf16Range
            ))
        }

        return segments
    }

    static func utf16Range(in text: String, start: Int, end: Int) -> NSRange? {
        guard start >= 0, end <= text.count, start < end else { return nil }
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        return NSRange(startIndex..<endIndex, in: text)
    }

    static func substring(of text: String, segment: TajweedResolvedSegment) -> String {
        let startIndex = text.index(text.startIndex, offsetBy: segment.start)
        let endIndex = text.index(text.startIndex, offsetBy: segment.end)
        return String(text[startIndex..<endIndex])
    }
}

private final class TajweedTextLayout {
    struct LineSlice {
        let stringRange: NSRange
        let origin: CGPoint
        let line: CTLine
        let imageBounds: CGRect
    }

    private let textStorage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(size: CGSize(width: 1, height: tajweedMeasurementHeight))
    private var attributedString = NSAttributedString()
    private var framesetter: CTFramesetter?
    private var cachedLineSlices: [LineSlice]?
    private var cachedFrameHeight: CGFloat?

    init() {
        layoutManager.allowsNonContiguousLayout = false
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func apply(attributedString: NSAttributedString) {
        textStorage.setAttributedString(attributedString)
        self.attributedString = attributedString
        framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        cachedLineSlices = nil
        cachedFrameHeight = nil
    }

    func setWidth(_ width: CGFloat) {
        let clampedWidth = max(width, 1)
        guard textContainer.size.width != clampedWidth else { return }
        textContainer.size = CGSize(width: clampedWidth, height: tajweedMeasurementHeight)
        cachedLineSlices = nil
        cachedFrameHeight = nil
    }

    func usedRect() -> CGRect {
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer)
    }

    func lineSlices() -> [LineSlice] {
        if let cachedLineSlices {
            return cachedLineSlices
        }

        guard let framesetter else { return [] }

        let frameHeight = drawingHeight()
        let path = CGPath(
            rect: CGRect(x: 0, y: 0, width: textContainer.size.width, height: frameHeight),
            transform: nil
        )
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

        let resolvedSlices = zip(lines, origins).map { line, origin in
            let range = CTLineGetStringRange(line)
            return LineSlice(
                stringRange: NSRange(location: range.location, length: range.length),
                origin: origin,
                line: line,
                imageBounds: CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
            )
        }
        cachedLineSlices = resolvedSlices
        return resolvedSlices
    }

    func drawingHeight() -> CGFloat {
        if let cachedFrameHeight {
            return cachedFrameHeight
        }

        layoutManager.ensureLayout(for: textContainer)
        let textKitHeight = ceil(layoutManager.usedRect(for: textContainer).height)
        let coreTextHeight: CGFloat
        if let framesetter {
            let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: 0),
                nil,
                CGSize(width: textContainer.size.width, height: .greatestFiniteMagnitude),
                nil
            )
            coreTextHeight = ceil(suggestedSize.height)
        } else {
            coreTextHeight = 0
        }

        let height = max(textKitHeight, coreTextHeight, 1)
        cachedFrameHeight = height
        return height
    }

    func draw(in context: CGContext) {
        for lineSlice in lineSlices() {
            context.textPosition = lineSlice.origin
            CTLineDraw(lineSlice.line, context)
        }
    }
}

@MainActor
final class TajweedRenderView: UIView {
    static let lineSpacing: CGFloat = 12

    private(set) var text: String = ""
    private(set) var resolvedSegments: [TajweedResolvedSegment] = []

    private let baseLayout = TajweedTextLayout()
    private var overlayLayouts: [TajweedRule: TajweedTextLayout] = [:]
    private var tapHandler: ((TajweedTap?) -> Void)?
    private var paragraphStyle = NSMutableParagraphStyle()
    private var baseTextColor: UIColor = UIColor(named: "niyaText") ?? .label

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        paragraphStyle.alignment = .right
        paragraphStyle.baseWritingDirection = .rightToLeft
        paragraphStyle.lineSpacing = Self.lineSpacing

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        verse: TajweedVerse,
        fontSize: CGFloat,
        showSupplementalRules: Bool,
        baseTextColor: UIColor = UIColor(named: "niyaText") ?? .label,
        onTap: @escaping (TajweedTap?) -> Void
    ) {
        text = verse.text
        tapHandler = onTap
        self.baseTextColor = baseTextColor
        resolvedSegments = TajweedTextResolver.resolveSegments(
            text: verse.text,
            annotations: verse.annotations,
            showSupplementalRules: showSupplementalRules
        )

        let font = UIFont.quranFont(script: .hafs, size: fontSize)
        apply(text: verse.text, font: font, color: baseTextColor, to: baseLayout)

        let visibleRules = Set(resolvedSegments.map(\.rule))
        overlayLayouts = Dictionary(uniqueKeysWithValues: visibleRules.map { rule in
            let layout = TajweedTextLayout()
            apply(text: verse.text, font: font, color: UIColor(rule.color), to: layout)
            return (rule, layout)
        })

        updateContainerWidths(to: bounds.width)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateContainerWidths(to: bounds.width)
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let fitted = sizeThatFits(CGSize(width: width, height: tajweedMeasurementHeight))
        return CGSize(width: UIView.noIntrinsicMetric, height: fitted.height)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width > 0 ? size.width : UIScreen.main.bounds.width
        updateContainerWidths(to: width)
        let usedRect = baseLayout.usedRect()
        return CGSize(width: width, height: max(ceil(usedRect.height), baseLayout.drawingHeight()))
    }

    override func draw(_ rect: CGRect) {
        guard !text.isEmpty,
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }

        updateContainerWidths(to: bounds.width)
        let drawingHeight = baseLayout.drawingHeight()

        context.saveGState()
        context.translateBy(x: 0, y: drawingHeight)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity

        baseLayout.draw(in: context)

        let groupedSegments = Dictionary(grouping: resolvedSegments, by: \.rule)
        for (rule, segments) in groupedSegments {
            guard let overlayLayout = overlayLayouts[rule] else {
                continue
            }

            context.saveGState()
            context.setBlendMode(.copy)

            let clipRects = segments.flatMap(coreTextRects(for:))
            guard !clipRects.isEmpty else {
                context.restoreGState()
                continue
            }

            context.addRects(clipRects)
            context.clip()
            overlayLayout.draw(in: context)
            context.restoreGState()
        }

        context.restoreGState()
    }

    func glyphRange(for segment: TajweedResolvedSegment) -> NSRange {
        baseLayout.layoutManager.glyphRange(
            forCharacterRange: segment.utf16Range,
            actualCharacterRange: nil
        )
    }

    func glyphSubranges(for segment: TajweedResolvedSegment) -> [NSRange] {
        let candidateRange = glyphRange(for: segment)
        guard candidateRange.length > 0 else { return [] }

        var subranges: [NSRange] = []
        var currentStart: Int?
        var currentLength = 0

        for glyphIndex in candidateRange.location..<NSMaxRange(candidateRange) {
            let characterIndex = baseLayout.layoutManager.characterIndexForGlyph(at: glyphIndex)
            let belongsToSegment = NSLocationInRange(characterIndex, segment.utf16Range)

            if belongsToSegment {
                if let start = currentStart, start + currentLength == glyphIndex {
                    currentLength += 1
                } else {
                    if let start = currentStart, currentLength > 0 {
                        subranges.append(NSRange(location: start, length: currentLength))
                    }
                    currentStart = glyphIndex
                    currentLength = 1
                }
            } else if let start = currentStart, currentLength > 0 {
                subranges.append(NSRange(location: start, length: currentLength))
                currentStart = nil
                currentLength = 0
            }
        }

        if let start = currentStart, currentLength > 0 {
            subranges.append(NSRange(location: start, length: currentLength))
        }

        return subranges
    }

    func boundingRect(for segment: TajweedResolvedSegment) -> CGRect {
        let rects = segmentRects(for: segment)
        guard let firstRect = rects.first else { return .null }
        return rects.dropFirst().reduce(firstRect) { partialResult, nextRect in
            partialResult.union(nextRect)
        }
    }

    func segment(containingUTF16Index utf16Index: Int) -> TajweedResolvedSegment? {
        resolvedSegments.first { $0.contains(utf16Index: utf16Index) }
    }

    private func apply(text: String, font: UIFont, color: UIColor, to layout: TajweedTextLayout) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        layout.apply(attributedString: NSAttributedString(string: text, attributes: attributes))
    }

    private func segmentRects(for segment: TajweedResolvedSegment) -> [CGRect] {
        let drawingHeight = baseLayout.drawingHeight()
        let rects = coreTextRects(for: segment).map { rect in
            CGRect(
                x: rect.minX,
                y: drawingHeight - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        }

        if !rects.isEmpty {
            return rects
        }

        let glyphRange = glyphRange(for: segment)
        let boundingRect = baseLayout.layoutManager.boundingRect(forGlyphRange: glyphRange, in: baseLayout.textContainer)
        guard !boundingRect.isNull, boundingRect.width > 0, boundingRect.height > 0 else {
            return []
        }

        return [boundingRect.insetBy(dx: -0.5, dy: -1)]
    }

    private func coreTextRects(for segment: TajweedResolvedSegment) -> [CGRect] {
        var rects: [CGRect] = []
        let drawingHeight = baseLayout.drawingHeight()

        for lineSlice in baseLayout.lineSlices() {
            let lineIntersection = NSIntersectionRange(lineSlice.stringRange, segment.utf16Range)
            guard lineIntersection.length > 0 else { continue }

            let lineStart = lineIntersection.location
            let lineEnd = NSMaxRange(lineIntersection)
            let startOffset = CTLineGetOffsetForStringIndex(lineSlice.line, lineStart, nil)
            let endOffset = CTLineGetOffsetForStringIndex(lineSlice.line, lineEnd, nil)
            let minX = lineSlice.origin.x + min(startOffset, endOffset)
            let maxX = lineSlice.origin.x + max(startOffset, endOffset)
            guard maxX > minX else { continue }

            let startGlyph = baseLayout.layoutManager.glyphIndexForCharacter(at: lineStart)
            var lineGlyphRange = NSRange(location: 0, length: 0)
            let lineRect = baseLayout.layoutManager.lineFragmentUsedRect(
                forGlyphAt: startGlyph,
                effectiveRange: &lineGlyphRange
            )
            guard !lineRect.isNull, lineRect.height > 0 else { continue }

            let clipRect = CGRect(
                x: minX,
                y: drawingHeight - lineRect.maxY,
                width: maxX - minX,
                height: lineRect.height
            )
            rects.append(clipRect)
        }

        return rects
    }

    private func updateContainerWidths(to width: CGFloat) {
        baseLayout.setWidth(width)
        for layout in overlayLayouts.values {
            layout.setWidth(width)
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard let segment = segment(at: point) else {
            tapHandler?(nil)
            return
        }

        let rect = boundingRect(for: segment)
        let position = CGPoint(x: rect.midX, y: rect.minY)
        tapHandler?(TajweedTap(rule: segment.rule, position: position))
    }

    private func segment(at point: CGPoint) -> TajweedResolvedSegment? {
        guard !text.isEmpty, bounds.contains(point) else { return nil }

        let usedRect = baseLayout.usedRect()
        guard usedRect.insetBy(dx: -12, dy: -12).contains(point) else { return nil }

        let utf16Length = text.utf16.count
        let index = baseLayout.layoutManager.characterIndex(
            for: point,
            in: baseLayout.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard index < utf16Length,
              let segment = segment(containingUTF16Index: index)
        else {
            return nil
        }

        let tapRect = boundingRect(for: segment).insetBy(dx: -10, dy: -10)
        return tapRect.contains(point) ? segment : nil
    }
}

struct TajweedTextView: UIViewRepresentable {
    @AppStorage(StorageKey.showSupplementalTajweedRules) private var showSupplementalTajweedRules: Bool = false
    let verse: TajweedVerse
    let fontSize: CGFloat
    let onTap: (TajweedTap?) -> Void

    func makeUIView(context: Context) -> TajweedRenderView {
        let view = TajweedRenderView()
        view.contentMode = .redraw
        return view
    }

    func updateUIView(_ uiView: TajweedRenderView, context: Context) {
        uiView.configure(
            verse: verse,
            fontSize: fontSize,
            showSupplementalRules: showSupplementalTajweedRules,
            onTap: onTap
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: TajweedRenderView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.window?.screen.bounds.width ?? UIScreen.main.bounds.width
        return uiView.sizeThatFits(CGSize(width: width, height: tajweedMeasurementHeight))
    }
}
