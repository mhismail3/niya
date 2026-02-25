import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("ContinueReadingCard")
struct ContinueReadingCardTests {

    private func makeSurah(totalVerses: Int) -> Surah {
        Surah(
            id: 2,
            name: "البقرة",
            transliteration: "Al-Baqarah",
            translation: "The Cow",
            type: "Medinan",
            totalVerses: totalVerses,
            startPage: 2
        )
    }

    private func makePosition(ayahId: Int) -> ReadingPosition {
        ReadingPosition(surahId: 2, lastAyahId: ayahId)
    }

    @Test func progressCalculation() {
        let card = ContinueReadingCard(surah: makeSurah(totalVerses: 100), position: makePosition(ayahId: 50))
        #expect(card.progress == 0.5)
    }

    @Test func progressAtStart() {
        let card = ContinueReadingCard(surah: makeSurah(totalVerses: 286), position: makePosition(ayahId: 1))
        #expect(card.progress > 0)
        #expect(card.progress < 0.01)
    }

    @Test func progressAtEnd() {
        let card = ContinueReadingCard(surah: makeSurah(totalVerses: 286), position: makePosition(ayahId: 286))
        #expect(card.progress == 1.0)
    }

    @Test func progressWithZeroVerses() {
        let card = ContinueReadingCard(surah: makeSurah(totalVerses: 0), position: makePosition(ayahId: 1))
        #expect(card.progress == 0.0)
    }

    @Test func relativeDateFormatting() {
        let formatted = Date.now.relativeFormatted
        #expect(!formatted.isEmpty)
    }
}
