import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("Tajweed Mapping with Waqf Marks")
struct TajweedMappingWaqfTests {

    private let waqfRange: ClosedRange<UInt32> = 0x06D6...0x06DC

    @Test func mappingPreservesAnnotationsWhenTargetHasWaqfMarks() {
        let service = TajweedService()
        // Surah 5 has waqf marks; verify annotations map correctly
        guard let verse = service.verse(surahId: 5, ayahId: 1) else {
            Issue.record("Surah 5:1 should exist in tajweed data")
            return
        }
        for ann in verse.annotations {
            #expect(ann.start >= 0, "Annotation start must be non-negative")
            #expect(ann.end <= verse.text.count, "Annotation end \(ann.end) exceeds text length \(verse.text.count)")
            #expect(ann.start < ann.end, "Annotation start must be less than end")
        }
    }

    @Test func annotationsValidForVersesWithWaqfMarks() {
        let service = TajweedService()
        let surahsToCheck = [2, 3, 4, 5, 18, 36]
        for surahId in surahsToCheck {
            var ayahId = 1
            while let verse = service.verse(surahId: surahId, ayahId: ayahId) {
                let hasWaqf = verse.text.unicodeScalars.contains { waqfRange.contains($0.value) }
                if hasWaqf {
                    for ann in verse.annotations {
                        #expect(ann.start >= 0, "\(surahId):\(ayahId) start < 0")
                        #expect(ann.end <= verse.text.count,
                                "\(surahId):\(ayahId) end \(ann.end) > len \(verse.text.count)")
                        #expect(ann.start < ann.end, "\(surahId):\(ayahId) empty annotation")
                    }
                }
                ayahId += 1
            }
        }
    }

    @Test func tajweedTextContainsWaqfMarks() {
        let service = TajweedService()
        // Verify that tajweed-processed text preserves waqf marks
        var foundWaqf = false
        for surahId in 1...10 {
            var ayahId = 1
            while let verse = service.verse(surahId: surahId, ayahId: ayahId) {
                if verse.text.unicodeScalars.contains(where: { waqfRange.contains($0.value) }) {
                    foundWaqf = true
                    break
                }
                ayahId += 1
            }
            if foundWaqf { break }
        }
        #expect(foundWaqf, "At least some tajweed verses should contain waqf marks")
    }
}
