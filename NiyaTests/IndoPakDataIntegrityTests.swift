import Foundation
import Testing
@testable import Niya

@Suite("IndoPak Data Integrity")
struct IndoPakDataIntegrityTests {

    private static let indoPakData: [String: [Verse]] = {
        guard let url = Bundle.main.url(forResource: "verses_indopak", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [Verse]].self, from: data)) ?? [:]
    }()

    private static let hafsData: [String: [Verse]] = {
        guard let url = Bundle.main.url(forResource: "verses_hafs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [Verse]].self, from: data)) ?? [:]
    }()

    @Test func allSurahsPresent() {
        for sid in 1...114 {
            #expect(Self.indoPakData[String(sid)] != nil, "Missing surah \(sid)")
        }
        #expect(Self.indoPakData.count == 114)
    }

    @Test func totalVerseCount() {
        let total = Self.indoPakData.values.reduce(0) { $0 + $1.count }
        #expect(total == 6236, "Expected 6236 verses, got \(total)")
    }

    @Test func versesPerSurahMatchHafs() {
        for sid in 1...114 {
            let key = String(sid)
            let ipCount = Self.indoPakData[key]?.count ?? 0
            let hafsCount = Self.hafsData[key]?.count ?? 0
            #expect(ipCount == hafsCount, "Surah \(sid): IndoPak=\(ipCount) vs Hafs=\(hafsCount)")
        }
    }

    @Test func noEmptyVerseText() {
        for (key, verses) in Self.indoPakData {
            for verse in verses {
                #expect(!verse.text.isEmpty, "Surah \(key) ayah \(verse.id) has empty text")
            }
        }
    }

    @Test func verseIdsSequential() {
        for sid in 1...114 {
            guard let verses = Self.indoPakData[String(sid)] else { continue }
            let ids = verses.map(\.id)
            let expected = Array(1...verses.count)
            #expect(ids == expected, "Surah \(sid) IDs not sequential: \(ids.prefix(5))...")
        }
    }

    @Test func pageNumbersPresent() {
        for (key, verses) in Self.indoPakData {
            for verse in verses {
                #expect(verse.page > 0, "Surah \(key) ayah \(verse.id) has page=\(verse.page)")
            }
        }
    }

    @Test func textDiffersFromHafs() {
        let samples: [(surah: Int, ayah: Int)] = [(1, 1), (2, 255), (36, 1), (112, 1)]
        for (surah, ayah) in samples {
            let key = String(surah)
            let ipText = Self.indoPakData[key]?.first(where: { $0.id == ayah })?.text ?? ""
            let hafsText = Self.hafsData[key]?.first(where: { $0.id == ayah })?.text ?? ""
            #expect(!ipText.isEmpty)
            #expect(!hafsText.isEmpty)
            #expect(ipText != hafsText, "Surah \(surah):\(ayah) text identical in both scripts — data not replaced")
        }
    }

    @Test func textContainsArabicCharacters() {
        let arabicRanges: [ClosedRange<UInt32>] = [
            0x0600...0x06FF,
            0x0750...0x077F,
            0xFB50...0xFDFF,
            0xFE70...0xFEFF,
        ]
        func hasArabic(_ text: String) -> Bool {
            text.unicodeScalars.contains { scalar in
                arabicRanges.contains { $0.contains(scalar.value) }
            }
        }
        for (key, verses) in Self.indoPakData {
            for verse in verses {
                #expect(hasArabic(verse.text), "Surah \(key) ayah \(verse.id) has no Arabic chars")
            }
        }
    }

    @Test func noUTF8BOM() {
        guard let firstVerse = Self.indoPakData["1"]?.first else {
            Issue.record("No verse 1:1")
            return
        }
        #expect(!firstVerse.text.hasPrefix("\u{FEFF}"), "Verse 1:1 starts with UTF-8 BOM")
    }

    @Test func sampleVersesFromEachJuz() {
        let samples: [(surahId: Int, ayahId: Int)] = [
            (1, 1), (2, 142), (2, 253), (3, 93), (4, 24),
            (4, 148), (5, 82), (6, 111), (7, 88), (8, 41),
            (9, 93), (11, 6), (12, 53), (15, 1), (17, 1),
            (18, 75), (21, 1), (23, 1), (25, 21), (27, 56),
            (29, 46), (33, 31), (36, 28), (39, 32), (41, 47),
            (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
        ]
        for (surahId, ayahId) in samples {
            let verse = Self.indoPakData[String(surahId)]?.first(where: { $0.id == ayahId })
            #expect(verse != nil, "Missing \(surahId):\(ayahId)")
            if let verse {
                #expect(!verse.text.isEmpty, "\(surahId):\(ayahId) has empty text")
            }
        }
    }

    @Test func translationFieldPresent() {
        for (key, verses) in Self.indoPakData {
            for verse in verses {
                #expect(!verse.translation.isEmpty, "Surah \(key) ayah \(verse.id) has empty translation")
            }
        }
    }
}
