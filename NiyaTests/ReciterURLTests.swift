import Testing
@testable import Niya

struct ReciterURLTests {
    @Test("All reciters produce valid surah stream URLs for edge surah IDs")
    func surahStreamURLsAreValid() {
        for reciter in Reciter.allCases {
            let url1 = reciter.surahStreamURL(surahId: 1)
            let url114 = reciter.surahStreamURL(surahId: 114)
            #expect(url1.scheme == "https", "Reciter \(reciter.rawValue) surah URL should be https")
            #expect(url114.scheme == "https", "Reciter \(reciter.rawValue) surah URL should be https")
            #expect(url1.host != nil, "Reciter \(reciter.rawValue) surah URL should have a host")
            #expect(url114.host != nil, "Reciter \(reciter.rawValue) surah URL should have a host")
        }
    }

    @Test("Reciters with per-verse audio produce valid verse stream URLs for edge verse numbers")
    func verseStreamURLsAreValid() {
        for reciter in Reciter.allCases {
            guard reciter.hasPerVerseAudio else { continue }
            let url1 = reciter.verseStreamURL(absoluteVerseNumber: 1)
            let url6236 = reciter.verseStreamURL(absoluteVerseNumber: 6236)
            #expect(url1 != nil, "Reciter \(reciter.rawValue) should produce verse URL for verse 1")
            #expect(url6236 != nil, "Reciter \(reciter.rawValue) should produce verse URL for verse 6236")
            #expect(url1?.scheme == "https")
            #expect(url6236?.scheme == "https")
        }
    }

    @Test("Reciters without per-verse audio return nil for verse stream URL")
    func noPerVerseRecitersReturnNil() {
        let noPerVerse: [Reciter] = [.noreenSiddiq, .bukhatir]
        for reciter in noPerVerse {
            #expect(!reciter.hasPerVerseAudio)
            #expect(reciter.verseStreamURL(absoluteVerseNumber: 1) == nil)
        }
    }

    @Test("Local filenames are correctly formatted for all reciters")
    func localFilenames() {
        for reciter in Reciter.allCases {
            let name = reciter.localFilename(for: 1)
            #expect(name.hasPrefix("audio_"), "Filename should start with audio_")
            #expect(name.hasSuffix("_1.mp3"), "Filename for surah 1 should end with _1.mp3")

            let name114 = reciter.localFilename(for: 114)
            #expect(name114.hasSuffix("_114.mp3"))
        }
    }

    @Test("Al-Afasy URLs use islamic.network CDN")
    func alAfasyURLs() {
        let surahURL = Reciter.alAfasy.surahStreamURL(surahId: 42)
        #expect(surahURL.host == "cdn.islamic.network")
        #expect(surahURL.path.contains("/42.mp3"))

        let verseURL = Reciter.alAfasy.verseStreamURL(absoluteVerseNumber: 100)
        #expect(verseURL?.host == "cdn.islamic.network")
        #expect(verseURL?.path.contains("/100.mp3") == true)
    }

    @Test("Noreen uses quranicaudio.com with zero-padded surah IDs")
    func noreenURLs() {
        let url = Reciter.noreenSiddiq.surahStreamURL(surahId: 3)
        #expect(url.host == "download.quranicaudio.com")
        #expect(url.path.contains("/003.mp3"))
    }

    @Test("Shuraym uses zero-padded surah IDs in surah stream")
    func shuraymZeroPad() {
        let url = Reciter.shuraym.surahStreamURL(surahId: 7)
        #expect(url.path.contains("/007.mp3"))
    }

    @Test("Non-padded reciters use plain surah IDs")
    func nonPaddedReciters() {
        let url = Reciter.sudais.surahStreamURL(surahId: 7)
        #expect(url.path.contains("/7.mp3"))
        #expect(!url.path.contains("/007.mp3"))
    }
}
