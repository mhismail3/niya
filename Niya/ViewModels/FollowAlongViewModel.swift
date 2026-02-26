import Foundation
import AVFoundation

@Observable
@MainActor
final class FollowAlongViewModel {
    var isPlaying = false
    var currentWordIndex: Int?
    var currentSurahId: Int?
    var currentVerseId: Int?
    var playbackSpeed: Float = 1.0
    var loopCount: Int = 1
    var autoAdvance = true

    private var currentLoop = 0
    private var trackingTask: Task<Void, Never>?
    private var wordPlayer: AVPlayer?
    private let audioService: AudioService
    private let wordDataService: WordDataService
    private let dataService: QuranDataService

    init(audioService: AudioService, wordDataService: WordDataService, dataService: QuranDataService) {
        self.audioService = audioService
        self.wordDataService = wordDataService
        self.dataService = dataService
    }

    static func wordIndex(for timeMs: Int, in words: [QuranWord]) -> Int? {
        var lo = 0, hi = words.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let word = words[mid]
            if timeMs < word.s {
                hi = mid - 1
            } else if timeMs >= word.e {
                lo = mid + 1
            } else {
                return mid
            }
        }
        if lo < words.count && timeMs < words[lo].s { return lo }
        return nil
    }

    func playVerse(surahId: Int, ayahId: Int) {
        guard let verseData = wordDataService.words(surahId: surahId, ayahId: ayahId),
              !verseData.w.isEmpty else { return }

        trackingTask?.cancel()
        currentSurahId = surahId
        currentVerseId = ayahId
        currentWordIndex = 0
        currentLoop = 0
        isPlaying = true

        let url = URL(string: verseData.au)!
        audioService.playWithSeek(url: url, seekMs: verseData.vs, rate: playbackSpeed)

        startWordTracking()
    }

    func stopTracking() {
        trackingTask?.cancel()
        trackingTask = nil
        isPlaying = false
        currentWordIndex = nil
        currentSurahId = nil
        currentVerseId = nil
        currentLoop = 0
        audioService.stop()
    }

    func togglePlayPause() {
        guard isPlaying || currentVerseId != nil else { return }
        audioService.togglePause()
        isPlaying = audioService.isPlaying
    }

    func setSpeed(_ speed: Float) {
        let clamped = min(max(speed, 0.5), 1.25)
        playbackSpeed = clamped
        if isPlaying {
            audioService.setRate(clamped)
        }
    }

    func tapWord(_ word: QuranWord) {
        wordPlayer?.pause()
        wordPlayer = nil
        let player = AVPlayer(url: word.audioURL)
        wordPlayer = player
        player.play()
    }

    func highlightState(for word: QuranWord, verseId: Int) -> WordHighlightState {
        guard currentVerseId == verseId, let idx = currentWordIndex else { return .upcoming }
        let wordIdx = word.p - 1
        if wordIdx == idx { return .current }
        if wordIdx < idx { return .completed }
        return .upcoming
    }

    func nextVerse() {
        guard let surahId = currentSurahId, let verseId = currentVerseId else { return }
        let totalVerses = dataService.surahs.first { $0.id == surahId }?.totalVerses ?? 0
        guard verseId < totalVerses else { return }
        playVerse(surahId: surahId, ayahId: verseId + 1)
    }

    func previousVerse() {
        guard let surahId = currentSurahId, let verseId = currentVerseId else { return }
        guard verseId > 1 else { return }
        playVerse(surahId: surahId, ayahId: verseId - 1)
    }

    private func startWordTracking() {
        trackingTask?.cancel()
        trackingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let timeMs = self.audioService.currentTimeMs
                guard let surahId = self.currentSurahId,
                      let verseId = self.currentVerseId,
                      let verseData = self.wordDataService.words(surahId: surahId, ayahId: verseId) else {
                    return
                }

                if timeMs >= verseData.ve {
                    self.handleVerseEnd()
                    return
                }

                let idx = Self.wordIndex(for: timeMs, in: verseData.w)
                if idx != self.currentWordIndex {
                    self.currentWordIndex = idx
                }

                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    private func handleVerseEnd() {
        currentLoop += 1
        if currentLoop < loopCount {
            guard let surahId = currentSurahId, let verseId = currentVerseId,
                  let verseData = wordDataService.words(surahId: surahId, ayahId: verseId) else { return }
            currentWordIndex = 0
            audioService.seekTo(ms: verseData.vs)
            audioService.setRate(playbackSpeed)
            startWordTracking()
        } else if autoAdvance {
            advanceToNextVerse()
        } else {
            isPlaying = false
            currentWordIndex = nil
            audioService.stop()
        }
    }

    private func advanceToNextVerse() {
        guard let surahId = currentSurahId, let verseId = currentVerseId else { return }
        let totalVerses = dataService.surahs.first { $0.id == surahId }?.totalVerses ?? 0
        if verseId < totalVerses {
            playVerse(surahId: surahId, ayahId: verseId + 1)
        } else {
            isPlaying = false
            currentWordIndex = nil
            audioService.stop()
        }
    }
}
