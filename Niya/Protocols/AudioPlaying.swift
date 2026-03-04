import Foundation

@MainActor protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var isLoading: Bool { get }
    var currentVerseID: VerseID? { get }
    var currentSurahId: Int? { get }
    var isFollowAlongActive: Bool { get }
    var isContinuousMode: Bool { get }
    var currentTimeMs: Int { get }
    var onVerseDidFinish: ((VerseID) -> Void)? { get set }
    var onVerseDidChange: ((VerseID) -> Void)? { get set }
    func play(url: URL, verseID: VerseID?, surahId: Int?)
    func transitionToVerse(url: URL, verseID: VerseID, surahId: Int)
    func playVerseInSurah(url: URL, startMs: Int, endMs: Int, verseID: VerseID, surahId: Int)
    func playSurahContinuous(url: URL, boundaries: [VerseBoundary], surahId: Int)
    func playWithSeek(url: URL, seekMs: Int, rate: Float)
    func seekToVerse(_ verseID: VerseID, startMs: Int)
    func seekTo(ms: Int, completion: (@Sendable () -> Void)?)
    func setRate(_ rate: Float)
    func stop()
    func pause()
    func resume()
    func togglePause()
    func configureSession()
    func streamURL(absoluteVerseNumber: Int, reciter: Reciter) -> URL?
    func surahStreamURL(surahId: Int, reciter: Reciter) -> URL
    func localSurahURL(surahId: Int, reciter: Reciter) -> URL?
}
