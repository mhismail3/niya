import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("Word Models")
struct WordModelTests {

    @Test func decodesQuranWord() throws {
        let json = """
        {"p":1,"t":"بِسْمِ","tr":"bis'mi","en":"In (the) name","a":"wbw/001_001_001.mp3","s":0,"e":580}
        """.data(using: .utf8)!
        let word = try JSONDecoder().decode(QuranWord.self, from: json)
        #expect(word.p == 1)
        #expect(word.t == "بِسْمِ")
        #expect(word.tr == "bis'mi")
        #expect(word.en == "In (the) name")
        #expect(word.a == "wbw/001_001_001.mp3")
        #expect(word.s == 0)
        #expect(word.e == 580)
    }

    @Test func quranWordId() {
        let word = QuranWord(p: 3, t: "ٱلرَّحْمَـٰنِ", tr: "l-raḥmāni", en: "the Most Gracious", a: "wbw/001_001_003.mp3", s: 1200, e: 1800)
        #expect(word.id == 3)
    }

    @Test func quranWordAudioURL() {
        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "wbw/001_001_001.mp3", s: 0, e: 580)
        #expect(word.audioURL?.absoluteString == "https://audio.qurancdn.com/wbw/001_001_001.mp3")
    }

    @Test func quranWordDuration() {
        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "wbw/001_001_001.mp3", s: 100, e: 580)
        #expect(word.durationMs == 480)
    }

    @Test func decodesVerseWordData() throws {
        let json = """
        {"au":"https://example.com/1.mp3","vs":0,"ve":6090,"w":[
            {"p":1,"t":"بِسْمِ","tr":"bis'mi","en":"In (the) name","a":"wbw/001_001_001.mp3","s":0,"e":580}
        ]}
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(VerseWordData.self, from: json)
        #expect(data.au == "https://example.com/1.mp3")
        #expect(data.vs == 0)
        #expect(data.ve == 6090)
        #expect(data.w.count == 1)
        #expect(data.w[0].p == 1)
    }

    @Test func decodesVerseWordDataWithMultipleWords() throws {
        let json = """
        {"au":"https://example.com/1.mp3","vs":0,"ve":6090,"w":[
            {"p":1,"t":"بِسْمِ","tr":"bis'mi","en":"In (the) name","a":"wbw/001_001_001.mp3","s":0,"e":580},
            {"p":2,"t":"ٱللَّهِ","tr":"allāhi","en":"(of) Allah","a":"wbw/001_001_002.mp3","s":580,"e":1200},
            {"p":3,"t":"ٱلرَّحْمَـٰنِ","tr":"l-raḥmāni","en":"the Most Gracious","a":"wbw/001_001_003.mp3","s":1200,"e":1800},
            {"p":4,"t":"ٱلرَّحِيمِ","tr":"l-raḥīmi","en":"the Most Merciful","a":"wbw/001_001_004.mp3","s":1800,"e":2400}
        ]}
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(VerseWordData.self, from: json)
        #expect(data.w.count == 4)
        #expect(data.w[3].en == "the Most Merciful")
    }

    @Test func highlightStateValues() {
        let current = WordHighlightState.current
        let completed = WordHighlightState.completed
        let upcoming = WordHighlightState.upcoming
        #expect(current != completed)
        #expect(completed != upcoming)
        #expect(current != upcoming)
    }

    @Test func quranWordWithUnicodeArabic() throws {
        let json = """
        {"p":1,"t":"بِسۡمِ ٱللَّهِ","tr":"bismi allahi","en":"In the name of Allah","a":"wbw/test.mp3","s":0,"e":500}
        """.data(using: .utf8)!
        let word = try JSONDecoder().decode(QuranWord.self, from: json)
        #expect(word.t.contains("ٱللَّهِ"))
    }

    @Test func quranWordWithEmptyTransliteration() throws {
        let json = """
        {"p":1,"t":"بِسْمِ","tr":"","en":"In (the) name","a":"wbw/test.mp3","s":0,"e":580}
        """.data(using: .utf8)!
        let word = try JSONDecoder().decode(QuranWord.self, from: json)
        #expect(word.tr.isEmpty)
    }

    @Test func quranWordZeroTiming() throws {
        let json = """
        {"p":1,"t":"بِسْمِ","tr":"bis'mi","en":"In (the) name","a":"wbw/test.mp3","s":0,"e":0}
        """.data(using: .utf8)!
        let word = try JSONDecoder().decode(QuranWord.self, from: json)
        #expect(word.s == 0)
        #expect(word.e == 0)
        #expect(word.durationMs == 0)
    }

    @Test func quranWordHashable() {
        let a = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "wbw/test.mp3", s: 0, e: 580)
        let b = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "wbw/test.mp3", s: 0, e: 580)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
