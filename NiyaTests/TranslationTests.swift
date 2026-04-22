import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TranslationEdition")
struct TranslationTests {

    @Test func translationIndexDecodes() throws {
        let editions = try CompressedJSON.decode([TranslationEdition].self, resource: "translations_index")
        #expect(editions.count >= 19)
        #expect(editions.allSatisfy { !$0.id.isEmpty && !$0.filename.isEmpty })
    }

    @Test func translationEditionRTL() {
        let urdu = TranslationEdition(id: "ur_maududi", language: "ur", languageName: "Urdu",
                                       name: "Maududi", author: "Syed Abul Aala Maududi",
                                       filename: "translation_ur_maududi.json")
        #expect(urdu.isRTL == true)

        let english = TranslationEdition(id: "en_sahih", language: "en", languageName: "English",
                                          name: "Sahih International", author: "Saheeh International",
                                          filename: "translation_en_sahih.json")
        #expect(english.isRTL == false)
    }

    @Test func translationEditionRTLPashto() {
        let pashto = TranslationEdition(id: "ps_abdulwali", language: "ps", languageName: "Pashto",
                                         name: "Abdulwali Khan", author: "Mufti Abdul Wali Khan al-Darwazi",
                                         filename: "translation_ps_abdulwali.json")
        #expect(pashto.isRTL == true)
    }

    @Test func translationEditionLTRItalianGreek() {
        let italian = TranslationEdition(id: "it_piccardo", language: "it", languageName: "Italian",
                                          name: "Piccardo", author: "Hamza Roberto Piccardo",
                                          filename: "translation_it_piccardo.json")
        let greek = TranslationEdition(id: "el_rwwad", language: "el", languageName: "Greek",
                                        name: "Rowwad", author: "Rowwad Translation Center / KFGQPC",
                                        filename: "translation_el_rwwad.json")
        #expect(italian.isRTL == false)
        #expect(greek.isRTL == false)
    }

    @Test func translationOverlayDecodes() throws {
        let overlay = try CompressedJSON.decode([String: String].self, resource: "translation_en_sahih")
        #expect(overlay.count == 6236)
        #expect(overlay["1:1"] != nil)
        #expect(overlay["114:6"] != nil)
    }

    @Test func allBundledTranslationsLoad() throws {
        let editions = try CompressedJSON.decode([TranslationEdition].self, resource: "translations_index")
        #expect(editions.count >= 19)

        for edition in editions {
            let name = edition.filename.replacingOccurrences(of: ".json", with: "")
            let overlay = try CompressedJSON.decode([String: String].self, resource: name)
            #expect(overlay.count == 6236, "Expected 6236 verses in \(edition.id), got \(overlay.count)")
        }
    }

    @Test func translationOverlayHasAllVerses() throws {
        let overlay = try CompressedJSON.decode([String: String].self, resource: "translation_en_sahih")

        let surahVerseCounts = [7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
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
                                5, 4, 5, 6]
        for (i, count) in surahVerseCounts.enumerated() {
            let surahId = i + 1
            for ayah in 1...count {
                #expect(overlay["\(surahId):\(ayah)"] != nil, "Missing \(surahId):\(ayah)")
            }
        }
    }

    @Test func requiredEditionsBundled() throws {
        let editions = try CompressedJSON.decode([TranslationEdition].self, resource: "translations_index")
        let byId = Dictionary(uniqueKeysWithValues: editions.map { ($0.id, $0) })

        let expected: [(id: String, language: String, languageName: String)] = [
            ("ps_abdulwali",  "ps", "Pashto"),
            ("ps_rwwad",      "ps", "Pashto"),
            ("fa_khorramdel", "fa", "Persian"),
            ("it_piccardo",   "it", "Italian"),
            ("es_garcia",     "es", "Spanish"),
            ("el_rwwad",      "el", "Greek"),
        ]

        for entry in expected {
            let edition = try #require(byId[entry.id], "Missing edition \(entry.id) in index")
            #expect(edition.language == entry.language)
            #expect(edition.languageName == entry.languageName)
        }
    }

    @Test func newEditionTextUsesExpectedScript() throws {
        // Quick sanity check that the bundled overlay for each new edition
        // contains characters from the expected Unicode block at 1:2 (or 1:1
        // as fallback). Catches accidental file swaps.
        let arabicRange: ClosedRange<UInt32> = 0x0600...0x06FF
        let greekRange: ClosedRange<UInt32> = 0x0370...0x03FF
        let latinRange: ClosedRange<UInt32> = 0x0041...0x024F

        let cases: [(id: String, range: ClosedRange<UInt32>)] = [
            ("translation_ps_abdulwali",  arabicRange),
            ("translation_ps_rwwad",      arabicRange),
            ("translation_fa_khorramdel", arabicRange),
            ("translation_it_piccardo",   latinRange),
            ("translation_es_garcia",     latinRange),
            ("translation_el_rwwad",      greekRange),
        ]

        for c in cases {
            let overlay = try CompressedJSON.decode([String: String].self, resource: c.id)
            let sample = overlay["1:2"] ?? overlay["1:1"] ?? ""
            let inRange = sample.unicodeScalars.contains { c.range.contains($0.value) }
            #expect(inRange, "\(c.id): '1:2' contains no characters in expected script range")
        }
    }
}
