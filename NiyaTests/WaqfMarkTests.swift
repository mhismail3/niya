import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("Waqf Mark Handling")
struct WaqfMarkTests {

    private let waqfRange: ClosedRange<UInt32> = 0x06D6...0x06DC

    // MARK: - Data integrity

    @Test func hafsDataContainsWaqfMarks() throws {
        let url = try #require(Bundle.main.url(forResource: "verses_hafs", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let surahs = try JSONDecoder().decode([String: [VerseEntry]].self, from: data)
        let verses = try #require(surahs["5"])
        let verse = verses[0]
        let waqfCount = verse.text.unicodeScalars.filter { waqfRange.contains($0.value) }.count
        #expect(waqfCount >= 2, "Surah 5:1 should have at least 2 waqf marks, found \(waqfCount)")
    }

    @Test func indoPakDataContainsWaqfMarks() throws {
        let url = try #require(Bundle.main.url(forResource: "verses_indopak", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let surahs = try JSONDecoder().decode([String: [VerseEntry]].self, from: data)
        var surahsWithWaqf = 0
        for (_, verses) in surahs {
            let hasWaqf = verses.contains { verse in
                verse.text.unicodeScalars.contains { waqfRange.contains($0.value) }
            }
            if hasWaqf { surahsWithWaqf += 1 }
        }
        #expect(surahsWithWaqf >= 10, "Expected waqf marks in many surahs, found in \(surahsWithWaqf)")
    }

    // MARK: - Stripping set correctness

    @Test func unsupportedMarksExcludeWaqfSigns() {
        for mark: UInt32 in [0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DC] {
            #expect(!TajweedService.unsupportedQuranMarks.contains(mark),
                    "Waqf mark U+\(String(mark, radix: 16, uppercase: true)) should NOT be stripped")
        }
    }

    @Test func unsupportedMarksExcludeSmallLowMeem() {
        #expect(!TajweedService.unsupportedQuranMarks.contains(0x06ED))
    }

    @Test func unsupportedMarksStillContainNonWaqfMarks() {
        let shouldStrip: [UInt32] = [0x06DD, 0x06DE, 0x06E9, 0x06EA, 0x06EB, 0x06EC]
        for mark in shouldStrip {
            #expect(TajweedService.unsupportedQuranMarks.contains(mark),
                    "Mark U+\(String(mark, radix: 16, uppercase: true)) should still be stripped")
        }
    }

    @Test func unsupportedMarksSetExactSize() {
        #expect(TajweedService.unsupportedQuranMarks.count == 6)
    }

    // MARK: - Display pipeline preserves waqf marks

    @Test func stripUnsupportedMarksPreservesWaqfInHafsText() {
        let textWithWaqf = "بِٱلۡعُقُودِۚ أُحِلَّتۡ"  // contains U+06DA (ۚ)
        let stripped = stripUnsupportedMarks(textWithWaqf)
        let hasWaqf = stripped.unicodeScalars.contains { waqfRange.contains($0.value) }
        #expect(hasWaqf, "Waqf marks must be preserved after stripping")
    }

    @Test func stripUnsupportedMarksRemovesEndOfAyah() {
        let textWithEoA = "test\u{06DD}more"
        let stripped = stripUnsupportedMarks(textWithEoA)
        let hasEoA = stripped.unicodeScalars.contains { $0.value == 0x06DD }
        #expect(!hasEoA, "End-of-ayah mark should be stripped")
    }

    @Test func stripUnsupportedMarksRemovesRubElHizb() {
        let text = "test\u{06DE}more"
        let stripped = stripUnsupportedMarks(text)
        #expect(!stripped.unicodeScalars.contains { $0.value == 0x06DE })
    }

    // MARK: - Helpers

    private func stripUnsupportedMarks(_ text: String) -> String {
        String(text.unicodeScalars.filter { !TajweedService.unsupportedQuranMarks.contains($0.value) })
    }
}

private struct VerseEntry: Decodable {
    let text: String
}
