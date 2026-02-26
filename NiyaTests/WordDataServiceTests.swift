import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("WordDataService")
struct WordDataServiceTests {

    @Test func initiallyNotLoaded() {
        let service = WordDataService()
        #expect(service.isLoaded == false)
    }

    @Test func wordsReturnsNilBeforeLoad() {
        let service = WordDataService()
        #expect(service.words(surahId: 1, ayahId: 1) == nil)
    }

    @Test func wordsReturnsNilForMissingSurah() {
        let service = WordDataService()
        #expect(service.words(surahId: 999, ayahId: 1) == nil)
    }

    @Test func wordsReturnsNilForMissingAyah() {
        let service = WordDataService()
        #expect(service.words(surahId: 1, ayahId: 999) == nil)
    }
}
