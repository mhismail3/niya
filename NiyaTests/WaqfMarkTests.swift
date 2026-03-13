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

    // MARK: - No stripping — all characters preserved

    @Test func cleanArabicTextPreservesAllQuranicMarks() {
        // Every Quranic mark in U+06D6-U+06ED range must survive cleanArabicText
        let allMarks = "\u{06D6}\u{06D7}\u{06D8}\u{06D9}\u{06DA}\u{06DB}\u{06DC}"
            + "\u{06DD}\u{06DE}\u{06E0}\u{06E1}\u{06E2}\u{06E3}\u{06E4}"
            + "\u{06E5}\u{06E6}\u{06E7}\u{06E8}\u{06E9}\u{06EA}\u{06EB}\u{06EC}\u{06ED}"
        let cleaned = TajweedService.cleanArabicText(allMarks)
        #expect(cleaned.unicodeScalars.count == allMarks.unicodeScalars.count,
                "No characters should be stripped — cascade font handles rendering")
    }

    @Test func cleanArabicTextPreservesWaqfMarks() {
        let textWithWaqf = "بِٱلۡعُقُودِۚ أُحِلَّتۡ"  // contains U+06DA (ۚ)
        let cleaned = TajweedService.cleanArabicText(textWithWaqf)
        let hasWaqf = cleaned.unicodeScalars.contains { waqfRange.contains($0.value) }
        #expect(hasWaqf, "Waqf marks must be preserved")
    }

    @Test func cleanArabicTextPreservesSmallLowMeem() {
        let text = "صَبْرًۭا"  // U+06ED
        let cleaned = TajweedService.cleanArabicText(text)
        #expect(cleaned.unicodeScalars.contains { $0.value == 0x06ED },
                "Small low meem must be preserved for cascade font rendering")
    }

    @Test func cleanArabicTextPreservesEndOfAyah() {
        let text = "test\u{06DD}more"
        let cleaned = TajweedService.cleanArabicText(text)
        #expect(cleaned.unicodeScalars.contains { $0.value == 0x06DD })
    }

    @Test func cleanArabicTextPreservesRubElHizb() {
        let text = "test\u{06DE}more"
        let cleaned = TajweedService.cleanArabicText(text)
        #expect(cleaned.unicodeScalars.contains { $0.value == 0x06DE })
    }

    // MARK: - Substitutions

    @Test func cleanArabicTextSubstitutesRoundedZero() {
        let text = "كَفَرُوا\u{06DF}"
        let cleaned = TajweedService.cleanArabicText(text)
        #expect(!cleaned.unicodeScalars.contains { $0.value == 0x06DF },
                "U+06DF should be substituted")
        #expect(cleaned.unicodeScalars.contains { $0.value == 0x06E0 },
                "Should be replaced with U+06E0")
    }

    @Test func cleanArabicTextSubstitutesAlefWavyHamza() {
        let text = "test\u{0672}end"
        let cleaned = TajweedService.cleanArabicText(text)
        #expect(!cleaned.unicodeScalars.contains { $0.value == 0x0672 })
        #expect(cleaned.unicodeScalars.contains { $0.value == 0x0670 })
    }

    @Test func cleanArabicTextSubstitutesDotlessBeh() {
        let text = "test\u{066E}end"
        let cleaned = TajweedService.cleanArabicText(text)
        #expect(!cleaned.unicodeScalars.contains { $0.value == 0x066E })
        #expect(cleaned.unicodeScalars.contains { $0.value == 0x0649 })
    }
}

private struct VerseEntry: Decodable {
    let text: String
}
