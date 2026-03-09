enum Juz {
    static let boundaries: [(surahId: Int, ayahId: Int)] = [
        (1, 1), (2, 142), (2, 253), (3, 93), (4, 24),
        (4, 148), (5, 82), (6, 111), (7, 88), (8, 41),
        (9, 93), (11, 6), (12, 53), (15, 1), (17, 1),
        (18, 75), (21, 1), (23, 1), (25, 21), (27, 56),
        (29, 46), (33, 31), (36, 28), (39, 32), (41, 47),
        (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
    ]

    static let versesPerSurah: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
        123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
        34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
        60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
        28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
        15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
        5, 4, 5, 6
    ]

    /// (surah, ayah) → absolute verse number 1–6236. Returns 0 for invalid input.
    static func absoluteVerseNumber(surah: Int, ayah: Int) -> Int {
        guard surah >= 1, surah <= versesPerSurah.count,
              ayah >= 1, ayah <= versesPerSurah[surah - 1] else { return 0 }
        return versesPerSurah.prefix(surah - 1).reduce(0, +) + ayah
    }

    /// Returns (number: 1–30, progress: 0.0–1.0) for the given position.
    /// Returns (1, 0.0) for invalid input.
    static func current(surahId: Int, ayahId: Int) -> (number: Int, progress: Double) {
        let pos = absoluteVerseNumber(surah: surahId, ayah: ayahId)
        guard pos > 0 else { return (1, 0.0) }

        var juzIndex = 0
        for i in (0..<boundaries.count).reversed() {
            let start = absoluteVerseNumber(surah: boundaries[i].surahId, ayah: boundaries[i].ayahId)
            if pos >= start {
                juzIndex = i
                break
            }
        }

        let juzStart = absoluteVerseNumber(surah: boundaries[juzIndex].surahId, ayah: boundaries[juzIndex].ayahId)
        let juzEnd: Int
        if juzIndex + 1 < boundaries.count {
            juzEnd = absoluteVerseNumber(surah: boundaries[juzIndex + 1].surahId, ayah: boundaries[juzIndex + 1].ayahId) - 1
        } else {
            juzEnd = 6236
        }

        let total = juzEnd - juzStart + 1
        let offset = pos - juzStart
        let progress = total > 1 ? Double(offset) / Double(total - 1) : 0.0

        return (juzIndex + 1, min(progress, 1.0))
    }
}
