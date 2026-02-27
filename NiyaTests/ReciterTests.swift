import Foundation
import Testing
@testable import Niya

@Suite("Reciter")
struct ReciterTests {

    @Test func displayNames() {
        #expect(Reciter.alAfasy.displayName == "Mishary Rashid Al-Afasy")
        #expect(Reciter.noreenSiddiq.displayName == "Noreen Mohammad Siddiq")
    }

    @Test func shortNames() {
        #expect(Reciter.alAfasy.shortName == "Al-Afasy")
        #expect(Reciter.noreenSiddiq.shortName == "Noreen Siddiq")
    }

    @Test func alAfasyHasPerVerseAudio() {
        #expect(Reciter.alAfasy.hasPerVerseAudio == true)
    }

    @Test func noreenLacksPerVerseAudio() {
        #expect(Reciter.noreenSiddiq.hasPerVerseAudio == false)
    }

    @Test func wordDataFilenames() {
        #expect(Reciter.alAfasy.wordDataFilename == "word_data")
        #expect(Reciter.noreenSiddiq.wordDataFilename == "noreen_word_data")
    }

    @Test func alAfasySurahURL() {
        let url = Reciter.alAfasy.surahStreamURL(surahId: 36)
        #expect(url.absoluteString == "https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/36.mp3")
    }

    @Test func noreenSurahURL() {
        let url = Reciter.noreenSiddiq.surahStreamURL(surahId: 1)
        #expect(url.absoluteString == "https://download.quranicaudio.com/quran/noreen_siddiq/001.mp3")
    }

    @Test func noreenSurahURLZeroPadded() {
        let url = Reciter.noreenSiddiq.surahStreamURL(surahId: 114)
        #expect(url.absoluteString == "https://download.quranicaudio.com/quran/noreen_siddiq/114.mp3")
    }

    @Test func alAfasyVerseURL() {
        let url = Reciter.alAfasy.verseStreamURL(absoluteVerseNumber: 7)
        #expect(url != nil)
        #expect(url!.absoluteString == "https://cdn.islamic.network/quran/audio/128/ar.alafasy/7.mp3")
    }

    @Test func noreenVerseURLIsNil() {
        let url = Reciter.noreenSiddiq.verseStreamURL(absoluteVerseNumber: 7)
        #expect(url == nil)
    }

    @Test func localFilenamesDistinct() {
        let a = Reciter.alAfasy.localFilename(for: 42)
        let n = Reciter.noreenSiddiq.localFilename(for: 42)
        #expect(a != n)
        #expect(a == "audio_alafasy_surah_42.mp3")
        #expect(n == "audio_noreen_surah_42.mp3")
    }

    @Test func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for reciter in Reciter.allCases {
            let data = try encoder.encode(reciter)
            let decoded = try decoder.decode(Reciter.self, from: data)
            #expect(decoded == reciter)
        }
    }

    @Test func rawValueMatchesExpected() {
        #expect(Reciter.alAfasy.rawValue == "alAfasy")
        #expect(Reciter.noreenSiddiq.rawValue == "noreenSiddiq")
    }
}
