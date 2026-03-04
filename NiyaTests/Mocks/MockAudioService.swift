import Foundation
@testable import Niya

@MainActor
final class MockAudioService: AudioPlaying {
    var isPlaying = false
    var isLoading = false
    var currentVerseID: VerseID?
    var currentSurahId: Int?
    var isFollowAlongActive = false
    var isContinuousMode = false
    var currentTimeMs: Int = 0
    var onVerseDidFinish: ((VerseID) -> Void)?
    var onVerseDidChange: ((VerseID) -> Void)?

    var playCallCount = 0
    var lastPlayedURL: URL?
    var lastPlayedVerseID: VerseID?
    var stopCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    var togglePauseCallCount = 0
    var setRateCallCount = 0
    var lastRate: Float?
    var seekToVerseCallCount = 0
    var playVerseInSurahCallCount = 0
    var playSurahContinuousCallCount = 0
    var playWithSeekCallCount = 0
    var configureSessionCallCount = 0

    func play(url: URL, verseID: VerseID? = nil, surahId: Int? = nil) {
        playCallCount += 1
        lastPlayedURL = url
        lastPlayedVerseID = verseID
        currentVerseID = verseID
        currentSurahId = surahId
        isPlaying = true
    }

    func transitionToVerse(url: URL, verseID: VerseID, surahId: Int) {
        currentVerseID = verseID
        currentSurahId = surahId
        isPlaying = true
    }

    func playVerseInSurah(url: URL, startMs: Int, endMs: Int, verseID: VerseID, surahId: Int) {
        playVerseInSurahCallCount += 1
        currentVerseID = verseID
        currentSurahId = surahId
        isPlaying = true
    }

    func playSurahContinuous(url: URL, boundaries: [VerseBoundary], surahId: Int) {
        playSurahContinuousCallCount += 1
        currentSurahId = surahId
        isContinuousMode = true
        if let first = boundaries.first {
            currentVerseID = first.verseID
        }
        isPlaying = true
    }

    func playWithSeek(url: URL, seekMs: Int, rate: Float) {
        playWithSeekCallCount += 1
        isFollowAlongActive = true
        isPlaying = true
    }

    func seekToVerse(_ verseID: VerseID, startMs: Int) {
        seekToVerseCallCount += 1
        currentVerseID = verseID
    }

    func seekTo(ms: Int, completion: (@Sendable () -> Void)? = nil) {
        completion?()
    }

    func setRate(_ rate: Float) {
        setRateCallCount += 1
        lastRate = rate
        if rate > 0 { isPlaying = true }
    }

    func stop() {
        stopCallCount += 1
        isPlaying = false
        isFollowAlongActive = false
        isContinuousMode = false
        currentVerseID = nil
        currentSurahId = nil
    }

    func pause() {
        pauseCallCount += 1
        isPlaying = false
    }

    func resume() {
        resumeCallCount += 1
        isPlaying = true
    }

    func togglePause() {
        togglePauseCallCount += 1
        isPlaying.toggle()
    }

    func configureSession() {
        configureSessionCallCount += 1
    }

    func streamURL(absoluteVerseNumber: Int, reciter: Reciter) -> URL? {
        URL(string: "https://example.com/audio/\(absoluteVerseNumber).mp3")
    }

    func surahStreamURL(surahId: Int, reciter: Reciter) -> URL {
        URL(string: "https://example.com/surah/\(surahId).mp3")!
    }

    func localSurahURL(surahId: Int, reciter: Reciter) -> URL? {
        nil
    }
}
