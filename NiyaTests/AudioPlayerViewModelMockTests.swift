import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("AudioPlayerViewModel Mock Tests")
struct AudioPlayerViewModelMockTests {

    private static let testSurah = Surah(
        id: 1, name: "الفاتحة", transliteration: "Al-Fatihah",
        translation: "The Opening", type: "meccan", totalVerses: 7, startPage: 1
    )

    private func makeMocks() -> (MockAudioService, MockQuranDataService, MockWordDataService) {
        let audio = MockAudioService()
        let data = MockQuranDataService()
        data.surahs = [Self.testSurah]
        let words = MockWordDataService()
        return (audio, data, words)
    }

    private func makeVM(
        audio: MockAudioService,
        data: MockQuranDataService,
        words: MockWordDataService,
        reciter: Reciter = .alAfasy
    ) -> AudioPlayerViewModel {
        AudioPlayerViewModel(audioService: audio, dataService: data, wordDataService: words, reciter: reciter)
    }

    // MARK: - playVerse per-verse reciter (Al-Afasy)

    @Test func playVerse_alAfasy_callsPlayWithCorrectURL() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 3)

        #expect(audio.playCallCount == 1)
        #expect(audio.lastPlayedURL?.absoluteString == "https://example.com/audio/3.mp3")
        #expect(audio.lastPlayedVerseID == VerseID(surahId: 1, ayahId: 3))
        #expect(audio.currentSurahId == 1)
    }

    @Test func playVerse_alAfasy_resetsCurrentLoop() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)
        vm.loopCount = 3

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(vm.currentLoop == 0)
    }

    // MARK: - playVerse per-surah reciter (Noreen)

    @Test func playVerse_noreen_autoAdvance_callsPlaySurahContinuous() {
        let (audio, data, words) = makeMocks()
        let verseData = VerseWordData(au: "https://example.com/surah.mp3", vs: 0, ve: 5000, w: [])
        words.allVerseDataResult = [
            (ayahId: 1, data: verseData),
            (ayahId: 2, data: VerseWordData(au: "https://example.com/surah.mp3", vs: 5000, ve: 10000, w: [])),
        ]
        let vm = makeVM(audio: audio, data: data, words: words, reciter: .noreenSiddiq)
        vm.autoAdvance = true
        vm.loopCount = 1

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(audio.playSurahContinuousCallCount == 1)
        #expect(audio.playVerseInSurahCallCount == 0)
        #expect(audio.playCallCount == 0)
    }

    @Test func playVerse_noreen_loopGreaterThanOne_callsPlayVerseInSurah() {
        let (audio, data, words) = makeMocks()
        let verseData = VerseWordData(
            au: "https://example.com/surah.mp3", vs: 0, ve: 5000,
            w: [QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)]
        )
        words.wordsResult["1:1"] = verseData
        let vm = makeVM(audio: audio, data: data, words: words, reciter: .noreenSiddiq)
        vm.loopCount = 2

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(audio.playVerseInSurahCallCount == 1)
        #expect(audio.playSurahContinuousCallCount == 0)
    }

    @Test func playVerse_noreen_noAutoAdvance_callsPlayVerseInSurah() {
        let (audio, data, words) = makeMocks()
        let verseData = VerseWordData(
            au: "https://example.com/surah.mp3", vs: 0, ve: 5000,
            w: [QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)]
        )
        words.wordsResult["1:1"] = verseData
        let vm = makeVM(audio: audio, data: data, words: words, reciter: .noreenSiddiq)
        vm.autoAdvance = false
        vm.loopCount = 1

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(audio.playVerseInSurahCallCount == 1)
    }

    // MARK: - playVerse per-surah reciter (Bukhatir)

    @Test func playVerse_bukhatir_noAutoAdvance_callsPlayVerseInSurah() {
        let (audio, data, words) = makeMocks()
        let verseData = VerseWordData(
            au: "https://example.com/surah.mp3", vs: 0, ve: 5000,
            w: [QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)]
        )
        words.wordsResult["1:1"] = verseData
        let vm = makeVM(audio: audio, data: data, words: words, reciter: .bukhatir)
        vm.autoAdvance = false
        vm.loopCount = 1

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(audio.playVerseInSurahCallCount == 1)
        #expect(audio.playSurahContinuousCallCount == 0)
        #expect(audio.playCallCount == 0)
    }

    @Test func playVerse_bukhatir_autoAdvance_callsPlaySurahContinuous() {
        let (audio, data, words) = makeMocks()
        let verseData = VerseWordData(au: "https://example.com/surah.mp3", vs: 0, ve: 5000, w: [])
        words.allVerseDataResult = [
            (ayahId: 1, data: verseData),
            (ayahId: 2, data: VerseWordData(au: "https://example.com/surah.mp3", vs: 5000, ve: 10000, w: [])),
        ]
        let vm = makeVM(audio: audio, data: data, words: words, reciter: .bukhatir)
        vm.autoAdvance = true
        vm.loopCount = 1

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(audio.playSurahContinuousCallCount == 1)
        #expect(audio.playVerseInSurahCallCount == 0)
        #expect(audio.playCallCount == 0)
    }

    // MARK: - playVerse fallback when word data missing

    @Test func playVerse_perSurahReciter_noWordData_fallsBackToPlaySurah() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words, reciter: .bukhatir)
        vm.autoAdvance = false
        vm.loopCount = 1

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(audio.playCallCount == 1)
        #expect(audio.playVerseInSurahCallCount == 0)
        #expect(audio.playSurahContinuousCallCount == 0)
        #expect(audio.currentSurahId == 1)
    }

    @Test func playVerse_perSurahReciter_noWordData_autoAdvance_fallsBackToPlaySurah() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words, reciter: .bukhatir)
        vm.autoAdvance = true
        vm.loopCount = 1

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(audio.playCallCount == 1)
        #expect(audio.playSurahContinuousCallCount == 0)
        #expect(audio.playVerseInSurahCallCount == 0)
        #expect(audio.currentSurahId == 1)
    }

    // MARK: - stop clears state

    @Test func stop_callsAudioServiceStop() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 1)
        vm.stop()

        #expect(audio.stopCallCount == 1)
        #expect(audio.isPlaying == false)
    }

    @Test func stop_afterMultiplePlays_callsStopOnce() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 1)
        vm.playVerse(surahId: 1, ayahId: 2)
        vm.stop()

        #expect(audio.stopCallCount == 1)
    }

    // MARK: - setSpeed clamps

    @Test func setSpeed_tooLow_clampsToMin() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.setSpeed(0.1)

        #expect(vm.playbackSpeed == 0.5)
        #expect(audio.lastRate == 0.5)
    }

    @Test func setSpeed_tooHigh_clampsToMax() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.setSpeed(2.0)

        #expect(vm.playbackSpeed == 1.25)
        #expect(audio.lastRate == 1.25)
    }

    @Test func setSpeed_withinRange_setsExactly() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.setSpeed(1.0)

        #expect(vm.playbackSpeed == 1.0)
        #expect(audio.lastRate == 1.0)
    }

    @Test func setSpeed_atBoundaries() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.setSpeed(0.5)
        #expect(vm.playbackSpeed == 0.5)

        vm.setSpeed(1.25)
        #expect(vm.playbackSpeed == 1.25)
    }

    // MARK: - setLoopCount resets currentLoop

    @Test func setLoopCount_resetsCurrentLoop() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.setLoopCount(3)

        #expect(vm.loopCount == 3)
        #expect(vm.currentLoop == 0)
    }

    @Test func setLoopCount_whilePlaying_restartsPlayback() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 2)
        let initialPlayCount = audio.playCallCount

        vm.setLoopCount(3)

        #expect(vm.currentLoop == 0)
        #expect(audio.playCallCount > initialPlayCount)
    }

    @Test func setLoopCount_whilePaused_doesNotRestartPlayback() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        audio.currentVerseID = VerseID(surahId: 1, ayahId: 1)
        audio.currentSurahId = 1
        audio.isPlaying = false

        let playCountBefore = audio.playCallCount
        vm.setLoopCount(2)

        #expect(vm.loopCount == 2)
        #expect(audio.playCallCount == playCountBefore)
    }

    // MARK: - nextVerse advances

    @Test func nextVerse_advancesToNextAyah() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 3)
        let playCountBefore = audio.playCallCount

        vm.nextVerse()

        #expect(audio.playCallCount > playCountBefore)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 4))
    }

    @Test func nextVerse_fromMiddle_playsCorrectVerse() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 5)
        vm.nextVerse()

        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 6))
    }

    // MARK: - nextVerse at last verse does nothing

    @Test func nextVerse_atLastVerse_doesNothing() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 7)
        let playCountBefore = audio.playCallCount

        vm.nextVerse()

        #expect(audio.playCallCount == playCountBefore)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 7))
    }

    // MARK: - previousVerse goes back

    @Test func previousVerse_goesBack() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 3)
        let playCountBefore = audio.playCallCount

        vm.previousVerse()

        #expect(audio.playCallCount > playCountBefore)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 2))
    }

    // MARK: - previousVerse at first verse does nothing

    @Test func previousVerse_atFirstVerse_doesNothing() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 1)
        let playCountBefore = audio.playCallCount

        vm.previousVerse()

        #expect(audio.playCallCount == playCountBefore)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 1))
    }

    // MARK: - isPlayingVerse returns correct state

    @Test func isPlayingVerse_whilePlaying_returnsTrue() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 3)

        #expect(vm.isPlayingVerse(surahId: 1, ayahId: 3) == true)
    }

    @Test func isPlayingVerse_differentVerse_returnsFalse() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 3)

        #expect(vm.isPlayingVerse(surahId: 1, ayahId: 5) == false)
    }

    @Test func isPlayingVerse_nothingPlaying_returnsFalse() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        #expect(vm.isPlayingVerse(surahId: 1, ayahId: 1) == false)
    }

    @Test func isPlayingVerse_afterStop_returnsFalse() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 3)
        vm.stop()

        #expect(vm.isPlayingVerse(surahId: 1, ayahId: 3) == false)
    }

    // MARK: - playSurah

    @Test func playSurah_callsPlayWithSurahURL() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playSurah(1)

        #expect(audio.playCallCount == 1)
        #expect(audio.lastPlayedURL?.absoluteString == "https://example.com/surah/1.mp3")
        #expect(audio.lastPlayedVerseID == nil)
        #expect(audio.currentSurahId == 1)
    }

    @Test func playSurah_setsIsPlaying() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playSurah(1)

        #expect(vm.isPlaying == true)
    }

    // MARK: - togglePause

    @Test func togglePause_whilePlaying_pauses() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 1)
        vm.togglePause()

        #expect(audio.togglePauseCallCount == 1)
        #expect(audio.isPlaying == false)
    }

    @Test func togglePause_whilePaused_resumes() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.playVerse(surahId: 1, ayahId: 1)
        vm.togglePause()
        vm.togglePause()

        #expect(audio.togglePauseCallCount == 2)
        #expect(audio.isPlaying == true)
    }

    // MARK: - Computed properties proxy correctly

    @Test func isPlaying_proxiesAudioService() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        #expect(vm.isPlaying == false)
        audio.isPlaying = true
        #expect(vm.isPlaying == true)
    }

    @Test func isLoading_proxiesAudioService() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        #expect(vm.isLoading == false)
        audio.isLoading = true
        #expect(vm.isLoading == true)
    }

    @Test func currentVerseID_proxiesAudioService() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        #expect(vm.currentVerseID == nil)
        audio.currentVerseID = VerseID(surahId: 2, ayahId: 5)
        #expect(vm.currentVerseID == VerseID(surahId: 2, ayahId: 5))
    }

    @Test func hasActiveSession_whenVerseIDSet() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        #expect(vm.hasActiveSession == false)

        audio.currentVerseID = VerseID(surahId: 1, ayahId: 1)
        #expect(vm.hasActiveSession == true)
    }

    @Test func hasActiveSession_whenSurahIdSet() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        audio.currentSurahId = 1
        #expect(vm.hasActiveSession == true)
    }

    // MARK: - nextVerse in continuous mode seeks

    @Test func nextVerse_continuousMode_seeksInsteadOfPlaying() {
        let (audio, data, words) = makeMocks()
        let verseData = VerseWordData(au: "https://example.com/surah.mp3", vs: 5000, ve: 10000, w: [])
        words.wordsResult["1:4"] = verseData
        let vm = makeVM(audio: audio, data: data, words: words)

        audio.currentVerseID = VerseID(surahId: 1, ayahId: 3)
        audio.currentSurahId = 1
        audio.isContinuousMode = true
        audio.isPlaying = true

        vm.nextVerse()

        #expect(audio.seekToVerseCallCount == 1)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 4))
    }

    @Test func previousVerse_continuousMode_seeksInsteadOfPlaying() {
        let (audio, data, words) = makeMocks()
        let verseData = VerseWordData(au: "https://example.com/surah.mp3", vs: 0, ve: 5000, w: [])
        words.wordsResult["1:2"] = verseData
        let vm = makeVM(audio: audio, data: data, words: words)

        audio.currentVerseID = VerseID(surahId: 1, ayahId: 3)
        audio.currentSurahId = 1
        audio.isContinuousMode = true
        audio.isPlaying = true

        vm.previousVerse()

        #expect(audio.seekToVerseCallCount == 1)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 2))
    }

    // MARK: - Speed applied after navigation

    @Test func nextVerse_appliesPlaybackSpeed() {
        let (audio, data, words) = makeMocks()
        let vm = makeVM(audio: audio, data: data, words: words)

        vm.setSpeed(0.75)
        vm.playVerse(surahId: 1, ayahId: 3)
        audio.setRateCallCount = 0

        vm.nextVerse()

        #expect(audio.setRateCallCount >= 1)
        #expect(audio.lastRate == 0.75)
    }
}
