import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Niya

@MainActor
@Suite("Tajweed Text Renderer")
struct TajweedTextRendererTests {

    private struct YunusCase {
        let ayahId: Int
        let word: String
    }

    private struct YunusBleedCase {
        let ayahId: Int
        let word: String
        let precedingGrapheme: String
        let precedingOffset: Int
        let followingGrapheme: String
        let followingOffset: Int
    }

    private let yunusCases: [YunusCase] = [
        .init(ayahId: 45, word: "يَحۡشُرُهُمۡ"),
        .init(ayahId: 43, word: "يُبۡصِرُونَ"),
        .init(ayahId: 32, word: "تُصۡرَفُونَ"),
        .init(ayahId: 30, word: "يَفۡتَرُونَ"),
        .init(ayahId: 28, word: "شُرَكَآؤُهُم"),
        .init(ayahId: 26, word: "قَتَرٞ"),
        .init(ayahId: 21, word: "ضَرَّآءَ"),
    ]

    private let yunusBleedCases: [YunusBleedCase] = [
        .init(ayahId: 21, word: "رَحۡمَةٗ", precedingGrapheme: "سَ", precedingOffset: 2, followingGrapheme: "حۡ", followingOffset: 1),
        .init(ayahId: 21, word: "ضَرَّآءَ", precedingGrapheme: "ضَ", precedingOffset: 1, followingGrapheme: "آ", followingOffset: 1),
        .init(ayahId: 21, word: "أَسۡرَعُ", precedingGrapheme: "سۡ", precedingOffset: 1, followingGrapheme: "عُ", followingOffset: 1),
    ]

    @Test func resolverUsesLastVisibleAnnotationPrecedence() {
        let text = "abcdef"
        let annotations = [
            TajweedAnnotation(rule: .ikhfa, start: 1, end: 5),
            TajweedAnnotation(rule: .maddNormal, start: 2, end: 4),
            TajweedAnnotation(rule: .raTafkheem, start: 3, end: 4),
        ]

        let segments = TajweedTextResolver.resolveSegments(
            text: text,
            annotations: annotations,
            showSupplementalRules: false
        )

        #expect(segments.map(\.rule) == [.ikhfa, .raTafkheem, .ikhfa])
        #expect(segments.map(\.start) == [1, 3, 4])
        #expect(segments.map(\.end) == [3, 4, 5])
        #expect(TajweedTextResolver.substring(of: text, segment: segments[0]) == "bc")
        #expect(TajweedTextResolver.substring(of: text, segment: segments[1]) == "d")
        #expect(TajweedTextResolver.substring(of: text, segment: segments[2]) == "e")
    }

    @Test func resolverCoalescesAdjacentCharactersWithSameFinalRule() {
        let text = "abcdef"
        let annotations = [
            TajweedAnnotation(rule: .raTafkheem, start: 1, end: 3),
            TajweedAnnotation(rule: .raTafkheem, start: 3, end: 5),
        ]

        let segments = TajweedTextResolver.resolveSegments(
            text: text,
            annotations: annotations,
            showSupplementalRules: false
        )

        #expect(segments.count == 1)
        #expect(segments[0].rule == .raTafkheem)
        #expect(segments[0].start == 1)
        #expect(segments[0].end == 5)
        #expect(TajweedTextResolver.substring(of: text, segment: segments[0]) == "bcde")
    }

    @Test func yunusRegressionSegmentsProduceGlyphRangesAndColoredBasePixels() throws {
        let service = TajweedService()
        let expectedColor = UIColor.raTafkheem.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        )

        for sample in yunusCases {
            let verse = try #require(service.verse(surahId: 10, ayahId: sample.ayahId))
            let actualView = makeRenderView(verse: verse, baseColor: nil)
            let referenceView = makeRenderView(
                verse: TajweedVerse(id: verse.id, text: verse.text, annotations: []),
                baseColor: expectedColor
            )

            let wordRange = try #require(graphemeRange(of: sample.word, in: verse.text))
            let segment = try #require(targetSegment(in: actualView.resolvedSegments, overlapping: wordRange))

            let glyphRange = actualView.glyphRange(for: segment)
            #expect(glyphRange.length > 0, "10:\(sample.ayahId) should map to a non-empty glyph range")

            let rect = actualView.boundingRect(for: segment)
            #expect(!rect.isNull && rect.width > 0 && rect.height > 0,
                    "10:\(sample.ayahId) should produce a non-empty glyph rect")

            let actualImage = renderImage(of: actualView)
            let referenceImage = renderImage(of: referenceView)
            let sampleRect = glyphSamplingRect(from: rect, in: actualImage)

            let actualCount = countPixels(
                in: actualImage,
                rect: sampleRect,
                matching: expectedColor
            )
            let referenceCount = countPixels(
                in: referenceImage,
                rect: sampleRect,
                matching: expectedColor
            )

            #expect(referenceCount > 12, "10:\(sample.ayahId) should have enough reference color coverage")
            #expect(actualCount * 4 >= referenceCount,
                    "10:\(sample.ayahId) should color the base glyph, not only the mark")
        }
    }

    @Test func yunusRegressionDoesNotColorPrecedingGraphemes() throws {
        let service = TajweedService()
        let expectedColor = UIColor.raTafkheem.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        )

        for sample in yunusBleedCases {
            let verse = try #require(service.verse(surahId: 10, ayahId: sample.ayahId))
            let actualView = makeRenderView(verse: verse, baseColor: nil)
            let actualImage = renderImage(of: actualView)

            let wordRange = try #require(graphemeRange(of: sample.word, in: verse.text))
            let segment = try #require(targetSegment(in: actualView.resolvedSegments, overlapping: wordRange))
            #expect(segment.start >= sample.precedingOffset,
                    "10:\(sample.ayahId) should have \(sample.precedingOffset) preceding graphemes")

            let precedingStart = segment.start - sample.precedingOffset
            let precedingRange = precedingStart..<(precedingStart + 1)
            let precedingText = graphemeSubstring(in: verse.text, range: precedingRange)
            #expect(precedingText == sample.precedingGrapheme,
                    "10:\(sample.ayahId) preceding grapheme mismatch for \(sample.word)")

            let precedingUtf16Range = try #require(
                TajweedTextResolver.utf16Range(
                    in: verse.text,
                    start: precedingRange.lowerBound,
                    end: precedingRange.upperBound
                )
            )
            let precedingSegment = TajweedResolvedSegment(
                rule: segment.rule,
                start: precedingRange.lowerBound,
                end: precedingRange.upperBound,
                utf16Range: precedingUtf16Range
            )

            let targetCount = countPixels(
                in: actualImage,
                rect: lowerGlyphRegion(from: actualView.boundingRect(for: segment), in: actualImage),
                matching: expectedColor
            )
            let precedingCount = countPixels(
                in: actualImage,
                rect: lowerGlyphRegion(from: actualView.boundingRect(for: precedingSegment), in: actualImage),
                matching: expectedColor
            )
            let followingStart = segment.end + (sample.followingOffset - 1)
            let followingRange = followingStart..<(followingStart + 1)
            let followingText = graphemeSubstring(in: verse.text, range: followingRange)
            #expect(followingText == sample.followingGrapheme,
                    "10:\(sample.ayahId) following grapheme mismatch for \(sample.word)")

            let followingUtf16Range = try #require(
                TajweedTextResolver.utf16Range(
                    in: verse.text,
                    start: followingRange.lowerBound,
                    end: followingRange.upperBound
                )
            )
            let followingSegment = TajweedResolvedSegment(
                rule: segment.rule,
                start: followingRange.lowerBound,
                end: followingRange.upperBound,
                utf16Range: followingUtf16Range
            )
            let followingCount = countPixels(
                in: actualImage,
                rect: lowerGlyphRegion(from: actualView.boundingRect(for: followingSegment), in: actualImage),
                matching: expectedColor
            )

            #expect(targetCount > 12, "10:\(sample.ayahId) target color coverage should be non-trivial")
            #expect(precedingCount * 5 <= targetCount,
                    "10:\(sample.ayahId) should not color the preceding grapheme for \(sample.word)")
            #expect(followingCount * 5 <= targetCount,
                    "10:\(sample.ayahId) should not color the following grapheme for \(sample.word)")
        }
    }

    private func makeRenderView(verse: TajweedVerse, baseColor: UIColor?) -> TajweedRenderView {
        let view = TajweedRenderView(frame: CGRect(x: 0, y: 0, width: 420, height: 10))
        view.configure(
            verse: verse,
            fontSize: 56,
            showSupplementalRules: false,
            baseTextColor: baseColor ?? (UIColor(named: "niyaText") ?? .label)
        ) { _ in }

        let fitted = view.sizeThatFits(CGSize(width: 420, height: tajweedMeasurementHeight))
        view.frame = CGRect(origin: .zero, size: fitted)
        view.layoutIfNeeded()
        return view
    }

    private func targetSegment(
        in segments: [TajweedResolvedSegment],
        overlapping wordRange: Range<Int>
    ) -> TajweedResolvedSegment? {
        segments.first { segment in
            segment.rule == .raTafkheem &&
            segment.start < wordRange.upperBound &&
            segment.end > wordRange.lowerBound
        }
    }

    private func graphemeRange(of word: String, in text: String) -> Range<Int>? {
        guard let range = text.range(of: word) else { return nil }
        let start = text.distance(from: text.startIndex, to: range.lowerBound)
        let end = text.distance(from: text.startIndex, to: range.upperBound)
        return start..<end
    }

    private func graphemeSubstring(in text: String, range: Range<Int>) -> String {
        let start = text.index(text.startIndex, offsetBy: range.lowerBound)
        let end = text.index(text.startIndex, offsetBy: range.upperBound)
        return String(text[start..<end])
    }

    private func renderImage(of view: UIView) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        return renderer.image { _ in
            view.draw(view.bounds)
        }
    }

    private func lowerGlyphRegion(from rect: CGRect, in image: UIImage) -> CGRect {
        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        let lowerSlice = CGRect(
            x: scaledRect.minX,
            y: scaledRect.minY + scaledRect.height * 0.35,
            width: scaledRect.width,
            height: scaledRect.height * 0.65
        )
        return lowerSlice.intersection(CGRect(
            x: 0,
            y: 0,
            width: image.size.width * scale,
            height: image.size.height * scale
        ))
    }

    private func glyphSamplingRect(from rect: CGRect, in image: UIImage) -> CGRect {
        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).insetBy(dx: -3, dy: -2)

        return scaledRect.intersection(CGRect(
            x: 0,
            y: 0,
            width: image.size.width * scale,
            height: image.size.height * scale
        ))
    }

    private func countPixels(in image: UIImage, rect: CGRect, matching color: UIColor) -> Int {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data)
        else {
            return 0
        }

        let target = rgbaComponents(for: color)
        let width = cgImage.width
        let bytesPerRow = cgImage.bytesPerRow
        let minX = max(Int(rect.minX.rounded(.down)), 0)
        let maxX = min(Int(rect.maxX.rounded(.up)), width)
        let minY = max(Int(rect.minY.rounded(.down)), 0)
        let maxY = min(Int(rect.maxY.rounded(.up)), cgImage.height)

        guard minX < maxX, minY < maxY else { return 0 }

        var count = 0
        for y in minY..<maxY {
            for x in minX..<maxX {
                let offset = y * bytesPerRow + x * 4
                let pixel = SIMD4<Double>(
                    Double(bytes[offset]) / 255.0,
                    Double(bytes[offset + 1]) / 255.0,
                    Double(bytes[offset + 2]) / 255.0,
                    Double(bytes[offset + 3]) / 255.0
                )
                guard pixel.w > 0.2 else { continue }

                let distance = abs(pixel.x - target.x)
                    + abs(pixel.y - target.y)
                    + abs(pixel.z - target.z)
                if distance < 0.55 {
                    count += 1
                }
            }
        }

        return count
    }

    private func rgbaComponents(for color: UIColor) -> SIMD4<Double> {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return SIMD4(Double(red), Double(green), Double(blue), Double(alpha))
    }
}
