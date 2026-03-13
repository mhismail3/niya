import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirDataIntegrity")
struct TafsirDataIntegrityTests {

    /// Verify the first verse of each surah (if present) is not duplicated from
    /// the previous surah. This catches the cross-surah boundary contamination
    /// bug where quran.com's verse-group mapping shifts content across surahs.
    @Test func noCrossSurahBoundaryContamination() throws {
        for edition in TafsirEdition.allCases {
            for surahN in 1...113 {
                let surahNext = surahN + 1

                guard let url1 = Bundle.main.url(
                    forResource: String(surahN),
                    withExtension: "json",
                    subdirectory: edition.bundleDirectory
                ),
                let data1 = try? Data(contentsOf: url1),
                let dict1 = try? JSONDecoder().decode([String: String].self, from: data1),
                let url2 = Bundle.main.url(
                    forResource: String(surahNext),
                    withExtension: "json",
                    subdirectory: edition.bundleDirectory
                ),
                let data2 = try? Data(contentsOf: url2),
                let dict2 = try? JSONDecoder().decode([String: String].self, from: data2)
                else { continue }

                let prevTexts = Set(dict1.values)

                // Find the first ayah key in surah N+1
                guard let firstKey = dict2.keys.compactMap({ Int($0) }).min(),
                      let firstText = dict2[String(firstKey)] else { continue }

                #expect(
                    !prevTexts.contains(firstText),
                    "\(edition.displayName): surah \(surahNext) ayah \(firstKey) contains text from surah \(surahN)"
                )
            }
        }
    }
}
