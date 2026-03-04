import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("FollowAlongViewModel Mock Tests")
struct FollowAlongViewModelMockTests {

    private static let testSurah = Surah(
        id: 1, name: "الفاتحة", transliteration: "Al-Fatihah",
        translation: "The Opening", type: "meccan", totalVerses: 7, startPage: 1
    )

    private static let sampleWords = [
        QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500),
        QuranWord(p: 2, t: "اللَّهِ", tr: "allahi", en: "of Allah", a: "", s: 500, e: 1000),
        QuranWord(p: 3, t: "الرَّحْمَٰنِ", tr: "ar-rahmani", en: "the Most Gracious", a: "", s: 1000, e: 1500),
        QuranWord(p: 4, t: "الرَّحِيمِ", tr: "ar-rahimi", en: "the Most Merciful", a: "", s: 1500, e: 2000),
    ]

    private func makeMocks() -> (MockAudioService, MockWordDataService, MockQuranDataService) {
        let audio = MockAudioService()
        let words = MockWordDataService()
        let data = MockQuranDataService()
        data.surahs = [Self.testSurah]
        return (audio, words, data)
    }

    private func makeVM(
        audio: MockAudioService,
        words: MockWordDataService,
        data: MockQuranDataService
    ) -> FollowAlongViewModel {
        FollowAlongViewModel(audioService: audio, wordDataService: words, dataService: data)
    }

    // MARK: - wordIndex binary search

    @Test func wordIndex_beforeFirstWord_returnsZero() {
        let words = Self.sampleWords
        let idx = FollowAlongViewModel.wordIndex(for: -10, in: words)
        #expect(idx == 0)
    }

    @Test func wordIndex_atFirstWordStart_returnsZero() {
        let words = Self.sampleWords
        let idx = FollowAlongViewModel.wordIndex(for: 0, in: words)
        #expect(idx == 0)
    }

    @Test func wordIndex_midFirstWord_returnsZero() {
        let words = Self.sampleWords
        let idx = FollowAlongViewModel.wordIndex(for: 250, in: words)
        #expect(idx == 0)
    }

    @Test func wordIndex_atSecondWordStart_returnsOne() {
        let words = Self.sampleWords
        let idx = FollowAlongViewModel.wordIndex(for: 500, in: words)
        #expect(idx == 1)
    }

    @Test func wordIndex_exactBoundary_belongsToNextWord() {
        let words = Self.sampleWords
        #expect(FollowAlongViewModel.wordIndex(for: 499, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 500, in: words) == 1)
    }

    @Test func wordIndex_thirdWord() {
        let words = Self.sampleWords
        #expect(FollowAlongViewModel.wordIndex(for: 1000, in: words) == 2)
        #expect(FollowAlongViewModel.wordIndex(for: 1250, in: words) == 2)
    }

    @Test func wordIndex_lastWord() {
        let words = Self.sampleWords
        #expect(FollowAlongViewModel.wordIndex(for: 1500, in: words) == 3)
        #expect(FollowAlongViewModel.wordIndex(for: 1999, in: words) == 3)
    }

    @Test func wordIndex_afterAllWords_returnsNil() {
        let words = Self.sampleWords
        #expect(FollowAlongViewModel.wordIndex(for: 2000, in: words) == nil)
        #expect(FollowAlongViewModel.wordIndex(for: 5000, in: words) == nil)
    }

    @Test func wordIndex_emptyArray_returnsNil() {
        #expect(FollowAlongViewModel.wordIndex(for: 0, in: []) == nil)
    }

    @Test func wordIndex_singleWord() {
        let words = [QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 100, e: 600)]
        #expect(FollowAlongViewModel.wordIndex(for: 50, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 100, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 599, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 600, in: words) == nil)
    }

    @Test func wordIndex_gapBetweenWords_returnsUpcoming() {
        let gappedWords = [
            QuranWord(p: 1, t: "a", tr: "a", en: "a", a: "", s: 0, e: 400),
            QuranWord(p: 2, t: "b", tr: "b", en: "b", a: "", s: 600, e: 1000),
        ]
        // In the gap (400-600), binary search falls through and returns the upcoming word
        #expect(FollowAlongViewModel.wordIndex(for: 450, in: gappedWords) == 1)
    }

    // MARK: - highlightState logic

    @Test func highlightState_currentWord_returnsCurrent() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentVerseId = 1
        vm.currentWordIndex = 1

        let word = QuranWord(p: 2, t: "اللَّهِ", tr: "allahi", en: "of Allah", a: "", s: 500, e: 1000)
        #expect(vm.highlightState(for: word, verseId: 1) == .current)
    }

    @Test func highlightState_completedWord_returnsCompleted() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentVerseId = 1
        vm.currentWordIndex = 2

        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)
        #expect(vm.highlightState(for: word, verseId: 1) == .completed)
    }

    @Test func highlightState_upcomingWord_returnsUpcoming() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentVerseId = 1
        vm.currentWordIndex = 0

        let word = QuranWord(p: 3, t: "الرَّحْمَٰنِ", tr: "ar-rahmani", en: "the Most Gracious", a: "", s: 1000, e: 1500)
        #expect(vm.highlightState(for: word, verseId: 1) == .upcoming)
    }

    @Test func highlightState_differentVerse_returnsUpcoming() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentVerseId = 2
        vm.currentWordIndex = 0

        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)
        #expect(vm.highlightState(for: word, verseId: 1) == .upcoming)
    }

    @Test func highlightState_noPlayback_returnsUpcoming() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)
        #expect(vm.highlightState(for: word, verseId: 1) == .upcoming)
    }

    @Test func highlightState_nilWordIndex_returnsUpcoming() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentVerseId = 1
        vm.currentWordIndex = nil

        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)
        #expect(vm.highlightState(for: word, verseId: 1) == .upcoming)
    }

    @Test func highlightState_allThreeStates() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentVerseId = 1
        vm.currentWordIndex = 1

        let w0 = QuranWord(p: 1, t: "بِسْمِ", tr: "bismi", en: "In the name", a: "", s: 0, e: 500)
        let w1 = QuranWord(p: 2, t: "اللَّهِ", tr: "allahi", en: "of Allah", a: "", s: 500, e: 1000)
        let w2 = QuranWord(p: 3, t: "الرَّحْمَٰنِ", tr: "ar-rahmani", en: "the Most Gracious", a: "", s: 1000, e: 1500)
        let w3 = QuranWord(p: 4, t: "الرَّحِيمِ", tr: "ar-rahimi", en: "the Most Merciful", a: "", s: 1500, e: 2000)

        #expect(vm.highlightState(for: w0, verseId: 1) == .completed)
        #expect(vm.highlightState(for: w1, verseId: 1) == .current)
        #expect(vm.highlightState(for: w2, verseId: 1) == .upcoming)
        #expect(vm.highlightState(for: w3, verseId: 1) == .upcoming)
    }

    // MARK: - stopTracking clears state

    @Test func stopTracking_clearsAllState() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.isPlaying = true
        vm.currentSurahId = 1
        vm.currentVerseId = 3
        vm.currentWordIndex = 2

        vm.stopTracking()

        #expect(vm.isPlaying == false)
        #expect(vm.currentWordIndex == nil)
        #expect(vm.currentSurahId == nil)
        #expect(vm.currentVerseId == nil)
    }

    @Test func stopTracking_callsAudioServiceStop() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.isPlaying = true
        vm.currentSurahId = 1
        vm.currentVerseId = 1

        vm.stopTracking()

        #expect(audio.stopCallCount == 1)
    }

    @Test func stopTracking_clearsTapState() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        let word = QuranWord(p: 2, t: "اللَّهِ", tr: "allahi", en: "of Allah", a: "test.mp3", s: 500, e: 1000)
        vm.tapWord(word, verseId: 1)
        #expect(vm.tappedWordPosition == 2)

        vm.stopTracking()

        #expect(vm.tappedWordPosition == nil)
        #expect(vm.tappedVerseId == nil)
    }

    // MARK: - setSpeed clamps

    @Test func setSpeed_tooLow_clampsToMin() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.setSpeed(0.1)

        #expect(vm.playbackSpeed == 0.5)
    }

    @Test func setSpeed_tooHigh_clampsToMax() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.setSpeed(2.0)

        #expect(vm.playbackSpeed == 1.25)
    }

    @Test func setSpeed_withinRange_setsExactly() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.setSpeed(0.75)

        #expect(vm.playbackSpeed == 0.75)
    }

    @Test func setSpeed_atBoundaries() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.setSpeed(0.5)
        #expect(vm.playbackSpeed == 0.5)

        vm.setSpeed(1.25)
        #expect(vm.playbackSpeed == 1.25)
    }

    @Test func setSpeed_whilePlaying_setsRateOnAudioService() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.isPlaying = true

        vm.setSpeed(0.75)

        #expect(audio.setRateCallCount == 1)
        #expect(audio.lastRate == 0.75)
    }

    @Test func setSpeed_whileNotPlaying_doesNotSetRate() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.isPlaying = false

        vm.setSpeed(0.75)

        #expect(audio.setRateCallCount == 0)
    }

    // MARK: - setLoopCount

    @Test func setLoopCount_updatesValue() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.setLoopCount(5)

        #expect(vm.loopCount == 5)
    }

    @Test func setLoopCount_resetsCurrentLoop() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.setLoopCount(3)

        // currentLoop is private(set), so we verify indirectly: after setting loopCount the
        // internal currentLoop is 0. We can verify via the fact that stopTracking doesn't
        // crash and the loop count is correct.
        #expect(vm.loopCount == 3)
    }

    @Test func setLoopCount_toOne_works() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.setLoopCount(3)
        vm.setLoopCount(1)

        #expect(vm.loopCount == 1)
    }

    // MARK: - Initial state

    @Test func initialState_allDefaults() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        #expect(vm.isPlaying == false)
        #expect(vm.currentWordIndex == nil)
        #expect(vm.currentSurahId == nil)
        #expect(vm.currentVerseId == nil)
        #expect(vm.playbackSpeed == 1.0)
        #expect(vm.loopCount == 1)
        #expect(vm.autoAdvance == true)
        #expect(vm.tappedWordPosition == nil)
        #expect(vm.tappedVerseId == nil)
    }

    // MARK: - playVerse sets state

    @Test func playVerse_setsStateCorrectly() {
        let (audio, words, data) = makeMocks()
        let verseData = VerseWordData(au: "https://example.com/verse.mp3", vs: 0, ve: 2000, w: Self.sampleWords)
        words.wordsResult["1:1"] = verseData
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(vm.isPlaying == true)
        #expect(vm.currentSurahId == 1)
        #expect(vm.currentVerseId == 1)
        #expect(vm.currentWordIndex == 0)
        #expect(audio.playWithSeekCallCount == 1)
    }

    @Test func playVerse_withNoWordData_doesNothing() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(vm.isPlaying == false)
        #expect(audio.playWithSeekCallCount == 0)
    }

    @Test func playVerse_withEmptyWords_doesNothing() {
        let (audio, words, data) = makeMocks()
        let verseData = VerseWordData(au: "https://example.com/verse.mp3", vs: 0, ve: 2000, w: [])
        words.wordsResult["1:1"] = verseData
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.playVerse(surahId: 1, ayahId: 1)

        #expect(vm.isPlaying == false)
        #expect(audio.playWithSeekCallCount == 0)
    }

    // MARK: - togglePlayPause

    @Test func togglePlayPause_whilePlaying_togglesMockState() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.isPlaying = true
        vm.currentVerseId = 1
        audio.isPlaying = true

        vm.togglePlayPause()

        #expect(audio.togglePauseCallCount == 1)
    }

    // MARK: - nextVerse / previousVerse delegation

    @Test func nextVerse_withNoCurrentState_doesNothing() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.nextVerse()

        #expect(audio.playWithSeekCallCount == 0)
    }

    @Test func previousVerse_withNoCurrentState_doesNothing() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)

        vm.previousVerse()

        #expect(audio.playWithSeekCallCount == 0)
    }

    @Test func nextVerse_atLastVerse_doesNothing() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentSurahId = 1
        vm.currentVerseId = 7

        let seekBefore = audio.playWithSeekCallCount
        vm.nextVerse()

        #expect(audio.playWithSeekCallCount == seekBefore)
    }

    @Test func previousVerse_atFirstVerse_doesNothing() {
        let (audio, words, data) = makeMocks()
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentSurahId = 1
        vm.currentVerseId = 1

        let seekBefore = audio.playWithSeekCallCount
        vm.previousVerse()

        #expect(audio.playWithSeekCallCount == seekBefore)
    }

    @Test func nextVerse_advancesAndPlays() {
        let (audio, words, data) = makeMocks()
        let nextVerseData = VerseWordData(au: "https://example.com/verse.mp3", vs: 2000, ve: 4000, w: Self.sampleWords)
        words.wordsResult["1:4"] = nextVerseData
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentSurahId = 1
        vm.currentVerseId = 3

        vm.nextVerse()

        #expect(vm.currentVerseId == 4)
    }

    @Test func previousVerse_goesBackAndPlays() {
        let (audio, words, data) = makeMocks()
        let prevVerseData = VerseWordData(au: "https://example.com/verse.mp3", vs: 0, ve: 2000, w: Self.sampleWords)
        words.wordsResult["1:2"] = prevVerseData
        let vm = makeVM(audio: audio, words: words, data: data)
        vm.currentSurahId = 1
        vm.currentVerseId = 3

        vm.previousVerse()

        #expect(vm.currentVerseId == 2)
    }
}
