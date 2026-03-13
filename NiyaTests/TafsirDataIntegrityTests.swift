import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirDataIntegrity")
struct TafsirDataIntegrityTests {

    /// Verify no surah N+1 verse 1 is a duplicate of surah N's last verse.
    /// Catches cross-surah boundary duplication from upstream digitization errors.
    @Test func noCrossSurahBoundaryDuplication() throws {
        for edition in TafsirEdition.allCases {
            for surahN in 1...113 {
                let surahNext = surahN + 1

                // Load both surahs via the service's public API
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

                guard let verse1Text = dict2["1"] else { continue }

                let lastKey = dict1.keys
                    .compactMap { Int($0) }
                    .max()
                    .map(String.init)
                guard let lastKey, let lastText = dict1[lastKey] else { continue }

                #expect(
                    lastText != verse1Text,
                    "\(edition.displayName): surah \(surahNext) verse 1 is a duplicate of surah \(surahN) verse \(lastKey)"
                )
            }
        }
    }
}
