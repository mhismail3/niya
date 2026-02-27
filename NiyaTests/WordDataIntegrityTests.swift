import Foundation
import Testing
@testable import Niya

@Suite("Word Data Integrity")
struct WordDataIntegrityTests {

    private static let allData: [Int: [Int: VerseWordData]] = {
        guard let url = Bundle.main.url(forResource: "word_data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String: VerseWordData]].self, from: data) else {
            return [:]
        }
        var result: [Int: [Int: VerseWordData]] = [:]
        for (surahKey, verses) in raw {
            guard let surahId = Int(surahKey) else { continue }
            var verseMap: [Int: VerseWordData] = [:]
            for (verseKey, wordData) in verses {
                guard let verseId = Int(verseKey) else { continue }
                verseMap[verseId] = wordData
            }
            result[surahId] = verseMap
        }
        return result
    }()

    private var allVerseData: [(surahId: Int, ayahId: Int, data: VerseWordData)] {
        var result: [(Int, Int, VerseWordData)] = []
        for surahId in Self.allData.keys.sorted() {
            guard let verses = Self.allData[surahId] else { continue }
            for ayahId in verses.keys.sorted() {
                result.append((surahId, ayahId, verses[ayahId]!))
            }
        }
        return result
    }

    @Test func positionsAreSequential() {
        for (surahId, ayahId, vd) in allVerseData {
            let positions = vd.w.map(\.p)
            let expected = Array(1...vd.w.count)
            #expect(positions == expected, "Surah \(surahId):\(ayahId) positions not sequential: \(positions)")
        }
    }

    @Test func everyWordHasAudioURL() {
        var emptyCount = 0
        for (_, _, vd) in allVerseData {
            for word in vd.w where word.a.isEmpty {
                emptyCount += 1
            }
        }
        // Allow up to 10 missing audio URLs across 77k+ words (known data gaps)
        #expect(emptyCount <= 10, "Too many words (\(emptyCount)) with empty audio URLs")
    }

    @Test func uniqueAudioURLsPerVerse() {
        for (surahId, ayahId, vd) in allVerseData {
            let urls = vd.w.map(\.a)
            let unique = Set(urls)
            #expect(urls.count == unique.count, "Surah \(surahId):\(ayahId) has duplicate audio URLs")
        }
    }

    @Test func baqarah5_specificWords() {
        guard let vd = Self.allData[2]?[5] else {
            Issue.record("No word data for 2:5")
            return
        }
        let positions = vd.w.map(\.p)
        #expect(positions == Array(1...vd.w.count))
        let audioURLs = vd.w.map(\.a)
        #expect(Set(audioURLs).count == audioURLs.count, "2:5 has duplicate audio URLs")
        #expect(vd.w.count >= 7 && vd.w.count <= 12, "2:5 word count \(vd.w.count) unexpected")
    }

    @Test func allVersesHaveWords() {
        for (surahId, ayahId, vd) in allVerseData {
            #expect(!vd.w.isEmpty, "Surah \(surahId):\(ayahId) has 0 words")
        }
    }

    @Test func timingsContinuous() {
        for (surahId, ayahId, vd) in allVerseData {
            guard vd.w.count >= 2 else { continue }
            for i in 1..<vd.w.count {
                let prev = vd.w[i - 1]
                let curr = vd.w[i]
                let gap = curr.s - prev.e
                #expect(gap <= 500, "Surah \(surahId):\(ayahId) gap of \(gap)ms between words \(i) and \(i+1)")
                #expect(gap >= -50, "Surah \(surahId):\(ayahId) negative overlap of \(gap)ms between words \(i) and \(i+1)")
            }
        }
    }

    @Test func sampleVersesFromEachJuz() {
        let samples: [(surahId: Int, ayahId: Int)] = [
            (1, 1), (2, 142), (2, 253), (3, 93), (4, 24),
            (4, 148), (5, 82), (6, 111), (7, 88), (8, 41),
            (9, 93), (11, 6), (12, 53), (15, 1), (17, 1),
            (18, 75), (21, 1), (23, 1), (25, 21), (27, 56),
            (29, 46), (33, 31), (36, 28), (39, 32), (41, 47),
            (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
            (108, 1), (108, 2), (108, 3),
        ]
        for (surahId, ayahId) in samples {
            let vd = Self.allData[surahId]?[ayahId]
            #expect(vd != nil, "No data for \(surahId):\(ayahId)")
            if let vd {
                #expect(!vd.w.isEmpty, "\(surahId):\(ayahId) has no words")
                #expect(!vd.au.isEmpty, "\(surahId):\(ayahId) has no audio URL")
            }
        }
    }

    @Test func audioURLsMatchSequentialPattern() {
        for (surahId, ayahId, vd) in allVerseData {
            for word in vd.w {
                let expected = String(
                    format: "wbw/%03d_%03d_%03d.mp3",
                    surahId, ayahId, word.p
                )
                #expect(
                    word.a == expected,
                    "Surah \(surahId):\(ayahId) word \(word.p) audio URL '\(word.a)' != '\(expected)'"
                )
            }
        }
    }
}
