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

                guard let dict1 = try? CompressedJSON.decode(
                    [String: String].self,
                    resource: String(surahN),
                    subdirectory: edition.bundleDirectory
                ),
                let dict2 = try? CompressedJSON.decode(
                    [String: String].self,
                    resource: String(surahNext),
                    subdirectory: edition.bundleDirectory
                )
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
