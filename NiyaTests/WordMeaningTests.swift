import Testing
import Foundation
@testable import Niya

@Suite("Word Meanings")
struct WordMeaningTests {

    private func makeWord(meaning: String? = nil) -> QuranWord {
        var word = QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "wbw/001_001_001.mp3", s: 0, e: 500)
        word.meaning = meaning
        return word
    }

    @Test func displayMeaningFallsBackToEnglish() {
        let word = makeWord()
        #expect(word.displayMeaning == "In the name")
    }

    @Test func displayMeaningUsesLocalizedWhenSet() {
        let word = makeWord(meaning: "کے نام سے")
        #expect(word.displayMeaning == "کے نام سے")
    }

    @Test func displayMeaningHandlesEmptyMeaning() {
        let word = makeWord(meaning: "")
        #expect(word.displayMeaning == "")
    }

    @Test func decodingDoesNotIncludeMeaning() throws {
        let json = """
        {"p":1,"t":"بِسْمِ","tr":"bismi","en":"In the name","a":"wbw/001_001_001.mp3","s":0,"e":500}
        """
        let data = json.data(using: .utf8)!
        let word = try JSONDecoder().decode(QuranWord.self, from: data)
        #expect(word.meaning == nil)
        #expect(word.displayMeaning == "In the name")
    }

    @Test func decodingIgnoresExtraMeaningField() throws {
        let json = """
        {"p":1,"t":"بِسْمِ","tr":"bismi","en":"In the name","a":"wbw/001_001_001.mp3","s":0,"e":500,"meaning":"extra"}
        """
        let data = json.data(using: .utf8)!
        let word = try JSONDecoder().decode(QuranWord.self, from: data)
        #expect(word.meaning == nil)
    }

    @Test func wordEqualityIncludesMeaning() {
        let word1 = makeWord(meaning: nil)
        let word2 = makeWord(meaning: "کے نام سے")
        #expect(word1 != word2)
    }

    @Test func wordEqualityBothNilMeaning() {
        let word1 = makeWord()
        let word2 = makeWord()
        #expect(word1 == word2)
    }

    @Test func supportedLanguagesAreCorrect() {
        #expect(WordDataService.supportedMeaningLanguages == Set(["ur", "bn", "tr", "id", "fa", "hi", "ta"]))
    }

    @Test @MainActor func meaningLoadForUnsupportedLanguageClearsOverlay() async {
        let service = WordDataService()
        await service.loadMeanings(language: "fr")
        #expect(service.currentMeaningLanguage == nil)
    }

    @Test @MainActor func meaningLoadForEnglishClearsOverlay() async {
        let service = WordDataService()
        await service.loadMeanings(language: "en")
        #expect(service.currentMeaningLanguage == nil)
    }
}
