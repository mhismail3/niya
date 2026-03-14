import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirService")
struct TafsirServiceTests {

    @Test func textReturnsNilForInvalidVerse() {
        let service = TafsirService()
        #expect(service.text(edition: .ibnKathir, surahId: 999, ayahId: 999) == nil)
    }

    @Test func textReturnsContentForValidVerse() {
        let service = TafsirService()
        let text = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        #expect(text != nil)
        #expect(text?.contains("Fatihah") == true)
    }

    @Test func differentEditionsSameVerse() {
        let service = TafsirService()
        let ik = service.text(edition: .ibnKathir, surahId: 1, ayahId: 1)
        let ia = service.text(edition: .ibnAbbas, surahId: 1, ayahId: 1)
        #expect(ik != nil)
        #expect(ia != nil)
        #expect(ik != ia)
    }

    @Test func allEditionsLoadSuccessfully() {
        let service = TafsirService()
        for edition in TafsirEdition.allCases {
            let text = service.text(edition: edition, surahId: 1, ayahId: 1)
            #expect(text != nil, "Edition \(edition.displayName) should have text for Al-Fatiha 1:1")
        }
    }

    @Test func sameSurahDifferentAyah() {
        let service = TafsirService()
        let t1 = service.text(edition: .ibnKathir, surahId: 2, ayahId: 1)
        let t2 = service.text(edition: .ibnKathir, surahId: 2, ayahId: 2)
        #expect(t1 != nil)
        #expect(t2 != nil)
        #expect(t1 != t2)
    }

    @Test func lastSurahLastVerse() {
        let service = TafsirService()
        let text = service.text(edition: .ibnKathir, surahId: 114, ayahId: 6)
        #expect(text != nil)
    }

    @Test func surahZeroReturnsNil() {
        let service = TafsirService()
        #expect(service.text(edition: .ibnKathir, surahId: 0, ayahId: 0) == nil)
    }

    @Test func cachedAfterFirstLoad() {
        let service = TafsirService()
        let t1 = service.text(edition: .ibnKathir, surahId: 36, ayahId: 1)
        let t2 = service.text(edition: .ibnKathir, surahId: 36, ayahId: 1)
        #expect(t1 == t2)
    }
}
