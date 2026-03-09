import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TajweedService")
struct TajweedServiceTests {

    @Test func allSurahsLoad() {
        let service = TajweedService()
        for surahId in 1...114 {
            let verse = service.verse(surahId: surahId, ayahId: 1)
            #expect(verse != nil, "Surah \(surahId) ayah 1 should exist")
            #expect(!verse!.text.isEmpty, "Surah \(surahId) ayah 1 text should not be empty")
        }
    }

    @Test func annotationRangesWithinBounds() {
        let service = TajweedService()
        for surahId in 1...114 {
            var ayahId = 1
            while let verse = service.verse(surahId: surahId, ayahId: ayahId) {
                let textLen = verse.text.count
                for ann in verse.annotations {
                    #expect(ann.start >= 0, "\(surahId):\(ayahId) start < 0")
                    #expect(ann.end <= textLen, "\(surahId):\(ayahId) end \(ann.end) > textLen \(textLen)")
                    #expect(ann.start < ann.end, "\(surahId):\(ayahId) start >= end")
                }
                ayahId += 1
            }
        }
    }

    @Test func knownVerseHasExpectedRules() {
        let service = TajweedService()
        // Al-Fatiha ayah 1 should have annotations
        let verse = service.verse(surahId: 1, ayahId: 1)!
        #expect(!verse.annotations.isEmpty)
        let rules = Set(verse.annotations.map(\.rule))
        #expect(rules.contains(.hamzatWasl))
    }

    @Test func clearCacheAndReload() {
        let service = TajweedService()
        _ = service.verse(surahId: 1, ayahId: 1)
        service.clearCache()
        // After clear, next call re-loads from bundle
        let verse = service.verse(surahId: 1, ayahId: 1)
        #expect(verse != nil)
    }

    @Test func invalidSurahReturnsNil() {
        let service = TajweedService()
        #expect(service.verse(surahId: 999, ayahId: 1) == nil)
    }

    @Test func unsupportedQuranMarksNonEmpty() {
        #expect(!TajweedService.unsupportedQuranMarks.isEmpty)
    }
}
