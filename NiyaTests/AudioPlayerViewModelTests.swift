import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("AudioPlayerViewModel Loop/Repeat")
struct AudioPlayerViewModelTests {

    private static let testSurah = Surah(
        id: 1, name: "الفاتحة", transliteration: "Al-Fatihah",
        translation: "The Opener", type: "Meccan", totalVerses: 7, startPage: 1
    )

    private func makeVM() -> (vm: AudioPlayerViewModel, audio: AudioService) {
        let audio = AudioService()
        let data = QuranDataService()
        data.surahs = [Self.testSurah]
        let vm = AudioPlayerViewModel(
            audioService: audio,
            dataService: data,
            wordDataService: WordDataService()
        )
        return (vm, audio)
    }

    /// Simulate a verse being actively played by the audio service.
    private func simulatePlaying(_ vid: VerseID, on audio: AudioService) {
        audio.currentVerseID = vid
        audio.currentSurahId = vid.surahId
        // play() sets isPlaying = true internally; mirror that state
        audio.isPlaying = true
    }

    // MARK: - Loop callback

    @Test func loopReplaysCurrentVerse() {
        let (vm, audio) = makeVM()
        vm.loopCount = 2

        let vid = VerseID(surahId: 1, ayahId: 1)
        simulatePlaying(vid, on: audio)

        // First verse end → should replay (currentLoop becomes 1, 1 < 2)
        audio.onVerseDidFinish?(vid)

        #expect(audio.currentVerseID == vid)
        #expect(audio.isPlaying == true)
    }

    @Test func loopAdvancesAfterAllLoopsCompleted() {
        let (vm, audio) = makeVM()
        vm.loopCount = 2

        let vid = VerseID(surahId: 1, ayahId: 1)
        simulatePlaying(vid, on: audio)

        // 1st end → loop
        audio.onVerseDidFinish?(vid)
        // 2nd end → advance
        audio.onVerseDidFinish?(vid)

        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 2))
    }

    @Test func noRepeatAdvancesImmediately() {
        let (vm, audio) = makeVM()
        vm.loopCount = 1
        _ = vm // silence unused warning

        let vid = VerseID(surahId: 1, ayahId: 1)
        simulatePlaying(vid, on: audio)

        audio.onVerseDidFinish?(vid)

        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 2))
    }

    @Test func stopsWhenAutoAdvanceOff() {
        let (vm, audio) = makeVM()
        vm.loopCount = 1
        vm.autoAdvance = false

        let vid = VerseID(surahId: 1, ayahId: 1)
        simulatePlaying(vid, on: audio)

        audio.onVerseDidFinish?(vid)

        // Callback runs clearNowPlaying but doesn't touch audioService state
        // (in real usage, playerDidFinish cleans up after the callback returns)
        #expect(audio.currentVerseID == vid)
    }

    @Test func threeLoopsReplaysTwiceThenAdvances() {
        let (vm, audio) = makeVM()
        vm.loopCount = 3

        let vid = VerseID(surahId: 1, ayahId: 1)
        simulatePlaying(vid, on: audio)

        // Ends 1 and 2 → replays
        audio.onVerseDidFinish?(vid)
        #expect(audio.currentVerseID == vid)
        audio.onVerseDidFinish?(vid)
        #expect(audio.currentVerseID == vid)

        // End 3 → advance
        audio.onVerseDidFinish?(vid)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 2))
    }

    // MARK: - setLoopCount

    @Test func setLoopCountRestartsPlayback() {
        let (vm, audio) = makeVM()

        let vid = VerseID(surahId: 1, ayahId: 3)
        simulatePlaying(vid, on: audio)

        vm.setLoopCount(3)

        #expect(vm.loopCount == 3)
        #expect(audio.currentVerseID == vid)
        #expect(audio.isPlaying == true)
    }

    @Test func setLoopCountToOneWhilePlaying() {
        let (vm, audio) = makeVM()

        let vid = VerseID(surahId: 1, ayahId: 1)
        simulatePlaying(vid, on: audio)

        vm.setLoopCount(1)

        // loopCount=1, verse finishes → should advance (no repeat)
        audio.onVerseDidFinish?(vid)
        #expect(audio.currentVerseID == VerseID(surahId: 1, ayahId: 2))
    }

    @Test func setLoopCountWhenPausedDoesNotRestartPlayback() {
        let (vm, audio) = makeVM()

        let vid = VerseID(surahId: 1, ayahId: 1)
        audio.currentVerseID = vid
        audio.currentSurahId = 1
        audio.isPlaying = false // paused

        vm.setLoopCount(2)

        // loopCount should be updated, but playback not restarted
        #expect(vm.loopCount == 2)
        #expect(audio.isPlaying == false)
    }

    // MARK: - Edge cases

    @Test func loopAtLastVerseDoesNotAdvancePastEnd() {
        let (vm, audio) = makeVM()
        vm.loopCount = 1

        // Ayah 7 is the last in Al-Fatihah (totalVerses: 7)
        let vid = VerseID(surahId: 1, ayahId: 7)
        simulatePlaying(vid, on: audio)

        audio.onVerseDidFinish?(vid)

        // nextAyah = 8 > totalVerses (7), so no advance
        // Callback falls through without starting new playback
        #expect(audio.currentVerseID == vid)
    }
}
