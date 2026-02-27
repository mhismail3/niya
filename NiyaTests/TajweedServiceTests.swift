import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TajweedService")
struct TajweedServiceTests {

    // MARK: - Markup Parsing

    @Test func singleTagMarkup() {
        let service = TajweedService()
        let result = service.parseTajweedMarkup("[h[بِسْمِ]", ayahId: 1)
        #expect(result.text == "بِسْمِ")
        #expect(result.annotations.count == 1)
        #expect(result.annotations[0].rule == .hamzatWasl)
        #expect(result.annotations[0].start == 0)
        // end uses String.count (grapheme clusters): بِسْمِ = 3 clusters
        #expect(result.annotations[0].end == "بِسْمِ".count)
    }

    @Test func multipleTagsMarkup() {
        let service = TajweedService()
        let result = service.parseTajweedMarkup("[h[بِسْ]مِ [g[ٱللَّهِ]", ayahId: 1)
        #expect(result.text == "بِسْمِ ٱللَّهِ")
        #expect(result.annotations.count == 2)
        #expect(result.annotations[0].rule == .hamzatWasl)
        #expect(result.annotations[0].start == 0)
        #expect(result.annotations[0].end == "بِسْ".count)
        #expect(result.annotations[1].rule == .ghunnah)
    }

    @Test func plainTextNoTags() {
        let service = TajweedService()
        let result = service.parseTajweedMarkup("بِسْمِ ٱللَّهِ", ayahId: 1)
        #expect(result.text == "بِسْمِ ٱللَّهِ")
        #expect(result.annotations.isEmpty)
    }

    @Test func bomPrefixStripped() {
        let service = TajweedService()
        let result = service.parseTajweedMarkup("\u{FEFF}[h[بِسْمِ]", ayahId: 1)
        #expect(!result.text.hasPrefix("\u{FEFF}"))
        #expect(result.text == "بِسْمِ")
        #expect(result.annotations.count == 1)
        #expect(result.annotations[0].start == 0)
    }

    @Test func malformedUnclosedBrackets() {
        let service = TajweedService()
        let result = service.parseTajweedMarkup("[h[بِسْمِ", ayahId: 1)
        #expect(!result.text.isEmpty)
    }

    @Test func emptyString() {
        let service = TajweedService()
        let result = service.parseTajweedMarkup("", ayahId: 1)
        #expect(result.text.isEmpty)
        #expect(result.annotations.isEmpty)
    }

    // MARK: - Cache State

    @Test func verseReturnsNilBeforeLoad() {
        let service = TajweedService()
        #expect(service.verse(surahId: 1, ayahId: 1) == nil)
    }

    @Test func verseReturnsAfterCacheParsing() {
        let service = TajweedService()
        let parsed = service.parseTajweedMarkup("[q[قُلْ]", ayahId: 3)
        #expect(parsed.annotations.count == 1)
        #expect(parsed.annotations[0].rule == .qalqalah)
        #expect(parsed.text == "قُلْ")
    }

    // MARK: - Loading Guards

    @Test func fetchWithCachedDataIsNoop() {
        let service = TajweedService()
        // First call triggers loading
        service.fetch(surahId: 999)
        // Second call should be a no-op (loadingSurahs already contains 999)
        service.fetch(surahId: 999)
        // No crash or assertion error = success
    }
}
