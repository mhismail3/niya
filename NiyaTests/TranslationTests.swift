import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TranslationEdition")
struct TranslationTests {

    @Test func translationIndexDecodes() throws {
        guard let url = Bundle.main.url(forResource: "translations_index", withExtension: "json") else {
            Issue.record("translations_index.json missing from bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let editions = try JSONDecoder().decode([TranslationEdition].self, from: data)
        #expect(editions.count >= 13)
        #expect(editions.allSatisfy { !$0.id.isEmpty && !$0.filename.isEmpty })
    }

    @Test func translationEditionRTL() {
        let urdu = TranslationEdition(id: "ur_jalandhry", language: "ur", languageName: "Urdu",
                                       name: "Jalandhry", author: "Jalandhry", filename: "translation_ur_jalandhry.json")
        #expect(urdu.isRTL == true)

        let english = TranslationEdition(id: "en_sahih", language: "en", languageName: "English",
                                          name: "Sahih International", author: "Saheeh International",
                                          filename: "translation_en_sahih.json")
        #expect(english.isRTL == false)
    }

    @Test func translationOverlayDecodes() throws {
        guard let url = Bundle.main.url(forResource: "translation_en_sahih", withExtension: "json") else {
            Issue.record("translation_en_sahih.json missing from bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let overlay = try JSONDecoder().decode([String: String].self, from: data)
        #expect(overlay.count == 6236)
        #expect(overlay["1:1"] != nil)
        #expect(overlay["114:6"] != nil)
    }

    @Test func allBundledTranslationsLoad() throws {
        guard let indexUrl = Bundle.main.url(forResource: "translations_index", withExtension: "json") else {
            Issue.record("translations_index.json missing from bundle")
            return
        }
        let indexData = try Data(contentsOf: indexUrl)
        let editions = try JSONDecoder().decode([TranslationEdition].self, from: indexData)

        for edition in editions {
            let name = edition.filename.replacingOccurrences(of: ".json", with: "")
            guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
                Issue.record("\(edition.filename) missing from bundle")
                continue
            }
            let data = try Data(contentsOf: url)
            let overlay = try JSONDecoder().decode([String: String].self, from: data)
            #expect(overlay.count == 6236, "Expected 6236 verses in \(edition.id), got \(overlay.count)")
        }
    }

    @Test func translationOverlayHasAllVerses() throws {
        guard let url = Bundle.main.url(forResource: "translation_en_sahih", withExtension: "json") else {
            Issue.record("translation_en_sahih.json missing from bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let overlay = try JSONDecoder().decode([String: String].self, from: data)

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
}
