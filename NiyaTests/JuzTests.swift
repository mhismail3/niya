import Foundation
import Testing
@testable import Niya

@Suite("Juz")
struct JuzTests {

    // MARK: - Data Integrity

    @Test func exactlyThirtyBoundaries() {
        #expect(Juz.boundaries.count == 30)
    }

    @Test func boundariesAreSorted() {
        for i in 1..<Juz.boundaries.count {
            let prev = Juz.absoluteVerseNumber(surah: Juz.boundaries[i - 1].surahId, ayah: Juz.boundaries[i - 1].ayahId)
            let curr = Juz.absoluteVerseNumber(surah: Juz.boundaries[i].surahId, ayah: Juz.boundaries[i].ayahId)
            #expect(curr > prev, "Boundary \(i) (\(curr)) should be > boundary \(i-1) (\(prev))")
        }
    }

    @Test func firstBoundaryIsFatihaVerseOne() {
        #expect(Juz.boundaries[0].surahId == 1)
        #expect(Juz.boundaries[0].ayahId == 1)
    }

    @Test func lastBoundaryIsAnNabaVerseOne() {
        #expect(Juz.boundaries[29].surahId == 78)
        #expect(Juz.boundaries[29].ayahId == 1)
    }

    @Test func versesPerSurahHas114Entries() {
        #expect(Juz.versesPerSurah.count == 114)
    }

    @Test func totalVersesEquals6236() {
        #expect(Juz.versesPerSurah.reduce(0, +) == 6236)
    }

    @Test func allBoundariesAreValid() {
        for (i, b) in Juz.boundaries.enumerated() {
            #expect(b.surahId >= 1 && b.surahId <= 114, "Boundary \(i+1) surahId \(b.surahId) out of range")
            #expect(b.ayahId >= 1, "Boundary \(i+1) ayahId \(b.ayahId) < 1")
            #expect(b.ayahId <= Juz.versesPerSurah[b.surahId - 1],
                    "Boundary \(i+1) ayahId \(b.ayahId) exceeds surah \(b.surahId) verse count \(Juz.versesPerSurah[b.surahId - 1])")
        }
    }

    // MARK: - absoluteVerseNumber

    @Test func absoluteVerseNumber_firstVerse() {
        #expect(Juz.absoluteVerseNumber(surah: 1, ayah: 1) == 1)
    }

    @Test func absoluteVerseNumber_lastOfFatiha() {
        #expect(Juz.absoluteVerseNumber(surah: 1, ayah: 7) == 7)
    }

    @Test func absoluteVerseNumber_firstOfBaqarah() {
        #expect(Juz.absoluteVerseNumber(surah: 2, ayah: 1) == 8)
    }

    @Test func absoluteVerseNumber_lastVerseOfQuran() {
        #expect(Juz.absoluteVerseNumber(surah: 114, ayah: 6) == 6236)
    }

    @Test func absoluteVerseNumber_invalidSurahZero() {
        #expect(Juz.absoluteVerseNumber(surah: 0, ayah: 1) == 0)
    }

    @Test func absoluteVerseNumber_invalidSurah115() {
        #expect(Juz.absoluteVerseNumber(surah: 115, ayah: 1) == 0)
    }

    @Test func absoluteVerseNumber_invalidAyahZero() {
        #expect(Juz.absoluteVerseNumber(surah: 1, ayah: 0) == 0)
    }

    @Test func absoluteVerseNumber_ayahExceedsCount() {
        #expect(Juz.absoluteVerseNumber(surah: 1, ayah: 8) == 0)
    }

    // MARK: - current() at boundaries

    @Test func currentAtEachBoundaryReturnsCorrectJuz() {
        for (i, b) in Juz.boundaries.enumerated() {
            let result = Juz.current(surahId: b.surahId, ayahId: b.ayahId)
            #expect(result.number == i + 1, "At boundary \(i+1) (\(b.surahId):\(b.ayahId)), expected juz \(i+1), got \(result.number)")
        }
    }

    @Test func currentAtEachBoundaryHasZeroProgress() {
        for (i, b) in Juz.boundaries.enumerated() {
            let result = Juz.current(surahId: b.surahId, ayahId: b.ayahId)
            #expect(result.progress == 0.0, "At boundary \(i+1), expected progress 0.0, got \(result.progress)")
        }
    }

    // MARK: - current() just before boundaries

    @Test func verseBeforeBoundaryReturnsPreviousJuz() {
        for i in 1..<Juz.boundaries.count {
            let boundaryAbsolute = Juz.absoluteVerseNumber(surah: Juz.boundaries[i].surahId, ayah: Juz.boundaries[i].ayahId)
            let beforeAbsolute = boundaryAbsolute - 1
            let (surah, ayah) = verseFromAbsolute(beforeAbsolute)
            let result = Juz.current(surahId: surah, ayahId: ayah)
            #expect(result.number == i, "Before boundary \(i+1), expected juz \(i), got \(result.number)")
        }
    }

    @Test func verseBeforeBoundaryHasHighProgress() {
        for i in 1..<Juz.boundaries.count {
            let boundaryAbsolute = Juz.absoluteVerseNumber(surah: Juz.boundaries[i].surahId, ayah: Juz.boundaries[i].ayahId)
            let beforeAbsolute = boundaryAbsolute - 1
            let (surah, ayah) = verseFromAbsolute(beforeAbsolute)
            let result = Juz.current(surahId: surah, ayahId: ayah)
            #expect(result.progress > 0.95, "Before boundary \(i+1), expected progress > 0.95, got \(result.progress)")
        }
    }

    // MARK: - current() edge cases

    @Test func lastVerseOfQuranIsJuz30() {
        let result = Juz.current(surahId: 114, ayahId: 6)
        #expect(result.number == 30)
        #expect(result.progress > 0.99)
    }

    @Test func firstVerseOfQuranIsJuz1() {
        let result = Juz.current(surahId: 1, ayahId: 1)
        #expect(result.number == 1)
        #expect(result.progress == 0.0)
    }

    @Test func midJuzProgressIsBetweenZeroAndOne() {
        // Middle of Juz 1 (Al-Baqarah verse 70, roughly midpoint)
        let result = Juz.current(surahId: 2, ayahId: 70)
        #expect(result.number == 1)
        #expect(result.progress > 0.0)
        #expect(result.progress < 1.0)
    }

    @Test func alBaqarahSpansMultipleJuz() {
        // Juz 1 ends before 2:142, Juz 2 starts at 2:142, Juz 3 starts at 2:253
        let j1 = Juz.current(surahId: 2, ayahId: 141)
        #expect(j1.number == 1)

        let j2 = Juz.current(surahId: 2, ayahId: 142)
        #expect(j2.number == 2)

        let j3 = Juz.current(surahId: 2, ayahId: 253)
        #expect(j3.number == 3)
    }

    @Test func invalidInputReturnsDefaults() {
        let result = Juz.current(surahId: 0, ayahId: 1)
        #expect(result.number == 1)
        #expect(result.progress == 0.0)
    }

    @Test func invalidAyahOutOfRange() {
        let result = Juz.current(surahId: 1, ayahId: 99)
        #expect(result.number == 1)
        #expect(result.progress == 0.0)
    }

    // MARK: - Helpers

    /// Convert absolute verse number (1-6236) back to (surahId, ayahId).
    private func verseFromAbsolute(_ absolute: Int) -> (surah: Int, ayah: Int) {
        var remaining = absolute
        for (i, count) in Juz.versesPerSurah.enumerated() {
            if remaining <= count {
                return (i + 1, remaining)
            }
            remaining -= count
        }
        return (114, 6)
    }
}
