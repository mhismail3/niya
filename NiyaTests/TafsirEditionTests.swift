import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirEdition")
struct TafsirEditionTests {

    @Test func displayNames() {
        for edition in TafsirEdition.allCases {
            #expect(!edition.displayName.isEmpty)
        }
    }

    @Test func authors() {
        for edition in TafsirEdition.allCases {
            #expect(!edition.author.isEmpty)
        }
    }

    @Test func subtitles() {
        for edition in TafsirEdition.allCases {
            #expect(!edition.subtitle.isEmpty)
        }
    }

    @Test func bundleFilenames() {
        #expect(TafsirEdition.ibnKathir.bundleFilename == "tafsir_ibn_kathir")
        #expect(TafsirEdition.maarifUlQuran.bundleFilename == "tafsir_maarif_ul_quran")
        #expect(TafsirEdition.ibnAbbas.bundleFilename == "tafsir_ibn_abbas")
        #expect(TafsirEdition.tazkirulQuran.bundleFilename == "tafsir_tazkirul_quran")
    }

    @Test func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for edition in TafsirEdition.allCases {
            let data = try encoder.encode(edition)
            let decoded = try decoder.decode(TafsirEdition.self, from: data)
            #expect(decoded == edition)
        }
    }

    @Test func allCasesCount() {
        #expect(TafsirEdition.allCases.count == 4)
    }

    @Test func rawValuesUnique() {
        let rawValues = TafsirEdition.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test func identifiableIds() {
        for edition in TafsirEdition.allCases {
            #expect(edition.id == edition.rawValue)
        }
    }
}
