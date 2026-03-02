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

    @Test func urlGeneration() {
        let url = TafsirEdition.ibnKathir.url(surahId: 2, ayahId: 255)
        #expect(url?.absoluteString == "https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/en-tafisr-ibn-kathir/2/255.json")

        let url2 = TafsirEdition.maarifUlQuran.url(surahId: 2, ayahId: 255)
        #expect(url2?.absoluteString == "https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/en-tafsir-maarif-ul-quran/2/255.json")
    }

    @Test func urlBoundaryValues() {
        let first = TafsirEdition.ibnKathir.url(surahId: 1, ayahId: 1)
        #expect(first?.absoluteString.contains("/1/1.json") == true)

        let last = TafsirEdition.ibnKathir.url(surahId: 114, ayahId: 6)
        #expect(last?.absoluteString.contains("/114/6.json") == true)
    }

    @Test func ibnKathirSlugHasTypo() {
        #expect(TafsirEdition.ibnKathir.rawValue.contains("tafisr"))
        #expect(!TafsirEdition.ibnKathir.rawValue.contains("tafsir"))
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

    @Test func entryDecoding() throws {
        let json = #"{"surah":1,"ayah":1,"text":"test"}"#
        let entry = try JSONDecoder().decode(TafsirEntry.self, from: Data(json.utf8))
        #expect(entry.surah == 1)
        #expect(entry.ayah == 1)
        #expect(entry.text == "test")
    }

    @Test func entryDecodingEmptyText() throws {
        let json = #"{"surah":1,"ayah":1,"text":""}"#
        let entry = try JSONDecoder().decode(TafsirEntry.self, from: Data(json.utf8))
        #expect(entry.text == "")
    }

    @Test func entryDecodingLargeText() throws {
        let largeText = String(repeating: "A", count: 60_000)
        let json = #"{"surah":1,"ayah":1,"text":"\#(largeText)"}"#
        let entry = try JSONDecoder().decode(TafsirEntry.self, from: Data(json.utf8))
        #expect(entry.text.count == 60_000)
    }

    @Test func entryDecodingMissingField() {
        let json = #"{"surah":1,"ayah":1}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TafsirEntry.self, from: Data(json.utf8))
        }
    }

    @Test func entryDecodingExtraFields() throws {
        let json = #"{"surah":1,"ayah":1,"text":"test","extra":"ignored"}"#
        let entry = try JSONDecoder().decode(TafsirEntry.self, from: Data(json.utf8))
        #expect(entry.text == "test")
    }
}
