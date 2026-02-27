import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("FollowAlongViewModel")
struct FollowAlongViewModelTests {

    // MARK: - wordIndex pure function tests

    @Test func wordIndexForTime_firstWord() {
        let words = makeWords(timings: [(0, 500), (500, 1000), (1000, 1500)])
        #expect(FollowAlongViewModel.wordIndex(for: 0, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 250, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 499, in: words) == 0)
    }

    @Test func wordIndexForTime_middleWord() {
        let words = makeWords(timings: [(0, 500), (500, 1000), (1000, 1500)])
        #expect(FollowAlongViewModel.wordIndex(for: 500, in: words) == 1)
        #expect(FollowAlongViewModel.wordIndex(for: 750, in: words) == 1)
        #expect(FollowAlongViewModel.wordIndex(for: 999, in: words) == 1)
    }

    @Test func wordIndexForTime_lastWord() {
        let words = makeWords(timings: [(0, 500), (500, 1000), (1000, 1500)])
        #expect(FollowAlongViewModel.wordIndex(for: 1000, in: words) == 2)
        #expect(FollowAlongViewModel.wordIndex(for: 1499, in: words) == 2)
    }

    @Test func wordIndexForTime_betweenWords() {
        let words = makeWords(timings: [(0, 400), (500, 1000)])
        // Gap at 400-500: should return upcoming word (index 1)
        #expect(FollowAlongViewModel.wordIndex(for: 450, in: words) == 1)
    }

    @Test func wordIndexForTime_beforeVerseStart() {
        let words = makeWords(timings: [(100, 500), (500, 1000)])
        // Before first word starts: return first word
        #expect(FollowAlongViewModel.wordIndex(for: 50, in: words) == 0)
    }

    @Test func wordIndexForTime_afterVerseEnd() {
        let words = makeWords(timings: [(0, 500), (500, 1000)])
        #expect(FollowAlongViewModel.wordIndex(for: 1000, in: words) == nil)
        #expect(FollowAlongViewModel.wordIndex(for: 1500, in: words) == nil)
    }

    @Test func wordIndexForTime_exactBoundary() {
        let words = makeWords(timings: [(0, 500), (500, 1000)])
        // s <= time < e: inclusive start, exclusive end
        #expect(FollowAlongViewModel.wordIndex(for: 500, in: words) == 1)
        #expect(FollowAlongViewModel.wordIndex(for: 499, in: words) == 0)
    }

    @Test func wordIndexForTime_singleWord() {
        let words = makeWords(timings: [(0, 1000)])
        #expect(FollowAlongViewModel.wordIndex(for: 0, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 500, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 999, in: words) == 0)
        #expect(FollowAlongViewModel.wordIndex(for: 1000, in: words) == nil)
    }

    @Test func wordIndexForTime_emptyWords() {
        let words: [QuranWord] = []
        #expect(FollowAlongViewModel.wordIndex(for: 0, in: words) == nil)
    }

    // MARK: - State tests

    @Test func initialState() {
        let vm = makeVM()
        #expect(vm.isPlaying == false)
        #expect(vm.currentWordIndex == nil)
        #expect(vm.currentSurahId == nil)
        #expect(vm.currentVerseId == nil)
        #expect(vm.playbackSpeed == 1.0)
        #expect(vm.loopCount == 1)
        #expect(vm.autoAdvance == true)
    }

    @Test func setSpeed_updatesState() {
        let vm = makeVM()
        vm.setSpeed(0.75)
        #expect(vm.playbackSpeed == 0.75)
    }

    @Test func speedClamp_withinRange() {
        let vm = makeVM()
        vm.setSpeed(0.1)
        #expect(vm.playbackSpeed == 0.5)
        vm.setSpeed(2.0)
        #expect(vm.playbackSpeed == 1.25)
    }

    @Test func stopTracking_clearsAllState() {
        let vm = makeVM()
        vm.currentSurahId = 1
        vm.currentVerseId = 1
        vm.currentWordIndex = 2
        vm.isPlaying = true
        vm.stopTracking()
        #expect(vm.isPlaying == false)
        #expect(vm.currentWordIndex == nil)
        #expect(vm.currentSurahId == nil)
        #expect(vm.currentVerseId == nil)
    }

    @Test func highlightState_currentVerse() {
        let vm = makeVM()
        vm.currentVerseId = 1
        vm.currentWordIndex = 1
        let word0 = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "test.mp3", s: 0, e: 500)
        let word1 = QuranWord(p: 2, t: "ٱللَّهِ", tr: "allāhi", en: "(of) Allah", a: "test.mp3", s: 500, e: 1000)
        let word2 = QuranWord(p: 3, t: "ٱلرَّحْمَـٰنِ", tr: "l-raḥmāni", en: "the Most Gracious", a: "test.mp3", s: 1000, e: 1500)
        #expect(vm.highlightState(for: word0, verseId: 1) == .completed)
        #expect(vm.highlightState(for: word1, verseId: 1) == .current)
        #expect(vm.highlightState(for: word2, verseId: 1) == .upcoming)
    }

    @Test func highlightState_differentVerse() {
        let vm = makeVM()
        vm.currentVerseId = 2
        vm.currentWordIndex = 0
        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "test.mp3", s: 0, e: 500)
        #expect(vm.highlightState(for: word, verseId: 1) == .upcoming)
    }

    @Test func highlightState_noPlayback() {
        let vm = makeVM()
        let word = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "test.mp3", s: 0, e: 500)
        #expect(vm.highlightState(for: word, verseId: 1) == .upcoming)
    }

    // MARK: - Tap highlight state

    @Test func tapWord_setsTappedState() {
        let vm = makeVM()
        let word = QuranWord(p: 3, t: "وَأُو۟لَـٰٓئِكَ", tr: "wa-ulāika", en: "And those", a: "wbw/002_005_005.mp3", s: 2000, e: 2500)
        vm.tapWord(word, verseId: 5)
        #expect(vm.tappedWordPosition == 3)
        #expect(vm.tappedVerseId == 5)
    }

    @Test func highlightState_tappedWord() {
        let vm = makeVM()
        let word = QuranWord(p: 2, t: "ٱللَّهِ", tr: "allāhi", en: "(of) Allah", a: "test.mp3", s: 500, e: 1000)
        vm.tapWord(word, verseId: 7)
        #expect(vm.highlightState(for: word, verseId: 7) == .current)
    }

    @Test func highlightState_tappedDifferentVerse() {
        let vm = makeVM()
        vm.currentVerseId = 1
        vm.currentWordIndex = 0
        let word = QuranWord(p: 2, t: "ٱللَّهِ", tr: "allāhi", en: "(of) Allah", a: "test.mp3", s: 500, e: 1000)
        vm.tapWord(word, verseId: 3)
        #expect(vm.highlightState(for: word, verseId: 3) == .current)
    }

    @Test func stopTracking_clearsTapState() {
        let vm = makeVM()
        let word = QuranWord(p: 2, t: "ٱللَّهِ", tr: "allāhi", en: "(of) Allah", a: "test.mp3", s: 500, e: 1000)
        vm.tapWord(word, verseId: 5)
        #expect(vm.tappedWordPosition == 2)
        vm.stopTracking()
        #expect(vm.tappedWordPosition == nil)
        #expect(vm.tappedVerseId == nil)
    }

    @Test func tapWord_clearsOldTapState() {
        let vm = makeVM()
        let word1 = QuranWord(p: 1, t: "بِسْمِ", tr: "bis'mi", en: "In (the) name", a: "test1.mp3", s: 0, e: 500)
        let word2 = QuranWord(p: 2, t: "ٱللَّهِ", tr: "allāhi", en: "(of) Allah", a: "test2.mp3", s: 500, e: 1000)
        vm.tapWord(word1, verseId: 1)
        #expect(vm.tappedWordPosition == 1)
        vm.tapWord(word2, verseId: 1)
        #expect(vm.tappedWordPosition == 2)
        #expect(vm.tappedVerseId == 1)
    }

    // MARK: - Helpers

    private func makeVM() -> FollowAlongViewModel {
        FollowAlongViewModel(
            audioService: AudioService(),
            wordDataService: WordDataService(),
            dataService: QuranDataService()
        )
    }

    private func makeWords(timings: [(Int, Int)]) -> [QuranWord] {
        timings.enumerated().map { idx, timing in
            QuranWord(
                p: idx + 1,
                t: "word\(idx + 1)",
                tr: "word\(idx + 1)",
                en: "word\(idx + 1)",
                a: "test.mp3",
                s: timing.0,
                e: timing.1
            )
        }
    }
}
