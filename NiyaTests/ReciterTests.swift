import Foundation
import Testing
@testable import Niya

@Suite("Reciter")
struct ReciterTests {

    @Test func allCasesCount() {
        #expect(Reciter.allCases.count == 9)
    }

    @Test(arguments: Reciter.allCases)
    func displayNameNotEmpty(reciter: Reciter) {
        #expect(!reciter.displayName.isEmpty)
    }

    @Test(arguments: Reciter.allCases)
    func shortNameNotEmpty(reciter: Reciter) {
        #expect(!reciter.shortName.isEmpty)
    }

    @Test func displayNames() {
        #expect(Reciter.alAfasy.displayName == "Mishary Rashid Al-Afasy")
        #expect(Reciter.noreenSiddiq.displayName == "Noreen Mohammad Siddiq")
        #expect(Reciter.abdulBaset.displayName == "AbdulBaset AbdulSamad")
        #expect(Reciter.sudais.displayName == "Abdur-Rahman as-Sudais")
        #expect(Reciter.shatri.displayName == "Abu Bakr al-Shatri")
        #expect(Reciter.haniRifai.displayName == "Hani ar-Rifai")
        #expect(Reciter.husary.displayName == "Mahmoud Khalil Al-Husary")
        #expect(Reciter.shuraym.displayName == "Sa'ud ash-Shuraym")
        #expect(Reciter.bukhatir.displayName == "Salah Bukhatir")
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

    @Test(arguments: [Reciter.abdulBaset, .sudais, .shatri, .haniRifai, .husary, .shuraym])
    func newRecitersHavePerVerseAudio(reciter: Reciter) {
        #expect(reciter.hasPerVerseAudio == true)
    }

    @Test func wordDataFilenames() {
        #expect(Reciter.alAfasy.wordDataFilename == "word_data")
        #expect(Reciter.noreenSiddiq.wordDataFilename == "noreen_word_data")
        #expect(Reciter.abdulBaset.wordDataFilename == "word_data_abdulbaset")
        #expect(Reciter.sudais.wordDataFilename == "word_data_sudais")
        #expect(Reciter.shatri.wordDataFilename == "word_data_shatri")
        #expect(Reciter.haniRifai.wordDataFilename == "word_data_hanirifai")
        #expect(Reciter.husary.wordDataFilename == "word_data_husary")
        #expect(Reciter.shuraym.wordDataFilename == "word_data_shuraym")
        #expect(Reciter.bukhatir.wordDataFilename == "word_data_bukhatir")
    }

    @Test func allRecitersHaveWordDataFilenames() {
        for reciter in Reciter.allCases {
            #expect(!reciter.wordDataFilename.isEmpty, "\(reciter.rawValue) missing wordDataFilename")
        }
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

    @Test func newReciterSurahURLFormat() {
        let url = Reciter.sudais.surahStreamURL(surahId: 2)
        #expect(url.absoluteString == "https://download.quranicaudio.com/qdc/abdurrahmaan_as_sudais/murattal/2.mp3")
    }

    @Test func shuraymSurahURLZeroPadded() {
        let url = Reciter.shuraym.surahStreamURL(surahId: 1)
        #expect(url.absoluteString == "https://download.quranicaudio.com/qdc/saud_ash-shuraym/murattal/001.mp3")
    }

    @Test func newReciterVerseURLFormat() {
        let url = Reciter.husary.verseStreamURL(absoluteVerseNumber: 1)
        #expect(url != nil)
        #expect(url!.absoluteString == "https://cdn.islamic.network/quran/audio/128/ar.husary/1.mp3")
    }

    @Test func reciterBitrates() {
        let url64 = Reciter.sudais.verseStreamURL(absoluteVerseNumber: 1)!
        #expect(url64.absoluteString.contains("/64/"))
        let url128 = Reciter.shatri.verseStreamURL(absoluteVerseNumber: 1)!
        #expect(url128.absoluteString.contains("/128/"))
    }

    @Test(arguments: [
        (Reciter.abdulBaset, "ar.abdulsamad"),
        (.sudais, "ar.abdurrahmaansudais"),
        (.shatri, "ar.shaatree"),
        (.haniRifai, "ar.hanirifai"),
        (.husary, "ar.husary"),
        (.shuraym, "ar.saoodshuraym"),
    ])
    func islamicNetworkCDNIds(reciter: Reciter, networkId: String) {
        let url = reciter.verseStreamURL(absoluteVerseNumber: 42)!
        #expect(url.absoluteString.contains(networkId))
    }

    @Test(arguments: Reciter.allCases)
    func surahURLsUseCorrectCDN(reciter: Reciter) {
        let url = reciter.surahStreamURL(surahId: 1)
        switch reciter {
        case .alAfasy:
            #expect(url.absoluteString.contains("cdn.islamic.network"))
        case .noreenSiddiq, .bukhatir:
            #expect(url.absoluteString.contains("quranicaudio.com/quran/"))
        default:
            #expect(url.absoluteString.contains("quranicaudio.com/qdc/"))
        }
    }

    @Test func localFilenamesDistinct() {
        let a = Reciter.alAfasy.localFilename(for: 42)
        let n = Reciter.noreenSiddiq.localFilename(for: 42)
        #expect(a != n)
        #expect(a == "audio_alafasy_surah_42.mp3")
        #expect(n == "audio_noreen_surah_42.mp3")
    }

    @Test func newReciterLocalFilenames() {
        #expect(Reciter.abdulBaset.localFilename(for: 1) == "audio_abdulbaset_surah_1.mp3")
        #expect(Reciter.sudais.localFilename(for: 114) == "audio_sudais_surah_114.mp3")
        #expect(Reciter.shatri.localFilename(for: 36) == "audio_shatri_surah_36.mp3")
        #expect(Reciter.haniRifai.localFilename(for: 55) == "audio_hanirifai_surah_55.mp3")
        #expect(Reciter.husary.localFilename(for: 67) == "audio_husary_surah_67.mp3")
        #expect(Reciter.shuraym.localFilename(for: 78) == "audio_shuraym_surah_78.mp3")
    }

    @Test(arguments: Reciter.allCases)
    func allLocalFilenamesUnique(reciter: Reciter) {
        let filenames = Reciter.allCases.map { $0.localFilename(for: 1) }
        let unique = Set(filenames)
        #expect(unique.count == filenames.count)
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

    @Test func bukhatirLacksPerVerseAudio() {
        #expect(Reciter.bukhatir.hasPerVerseAudio == false)
    }

    @Test func bukhatirVerseURLIsNil() {
        let url = Reciter.bukhatir.verseStreamURL(absoluteVerseNumber: 7)
        #expect(url == nil)
    }

    @Test func bukhatirSurahURL() {
        let url = Reciter.bukhatir.surahStreamURL(surahId: 1)
        #expect(url.absoluteString == "https://download.quranicaudio.com/quran/salaah_bukhaatir/001.mp3")
    }

    @Test func bukhatirSurahURLNonPaddedCheck() {
        let url = Reciter.bukhatir.surahStreamURL(surahId: 114)
        #expect(url.absoluteString == "https://download.quranicaudio.com/quran/salaah_bukhaatir/114.mp3")
    }

    @Test func bukhatirLocalFilename() {
        #expect(Reciter.bukhatir.localFilename(for: 1) == "audio_bukhatir_surah_1.mp3")
        #expect(Reciter.bukhatir.localFilename(for: 114) == "audio_bukhatir_surah_114.mp3")
    }

    @Test func bukhatirShortName() {
        #expect(Reciter.bukhatir.shortName == "Bukhatir")
    }

    @Test func rawValueMatchesExpected() {
        #expect(Reciter.alAfasy.rawValue == "alAfasy")
        #expect(Reciter.noreenSiddiq.rawValue == "noreenSiddiq")
        #expect(Reciter.abdulBaset.rawValue == "abdulBaset")
        #expect(Reciter.sudais.rawValue == "sudais")
        #expect(Reciter.shatri.rawValue == "shatri")
        #expect(Reciter.haniRifai.rawValue == "haniRifai")
        #expect(Reciter.husary.rawValue == "husary")
        #expect(Reciter.shuraym.rawValue == "shuraym")
        #expect(Reciter.bukhatir.rawValue == "bukhatir")
    }
}
