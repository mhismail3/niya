import Foundation
import AVFoundation
import MediaPlayer

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
    private(set) var tappedWordPosition: Int?
    private(set) var tappedVerseId: Int?

    private var currentLoop = 0
    private var seekingToStart = false
    private var trackingTask: Task<Void, Never>?
    private var wordPlayer: AVPlayer?
    private var tapObserver: NSObjectProtocol?
    private let audioService: any AudioPlaying
    private let wordDataService: any WordDataProviding
    private let dataService: any QuranDataProviding

    init(audioService: any AudioPlaying, wordDataService: any WordDataProviding, dataService: any QuranDataProviding) {
        self.audioService = audioService
        self.wordDataService = wordDataService
        self.dataService = dataService
    }

    private func updateNowPlaying() {
        var info = [String: Any]()
        if let surahId = currentSurahId, let verseId = currentVerseId {
            let surah = dataService.surah(id: surahId)
            info[MPMediaItemPropertyTitle] = "Ayah \(verseId) — Word by Word"
            info[MPMediaItemPropertyAlbumTitle] = surah?.transliteration ?? "Surah \(surahId)"
        }
        let reciterName = wordDataService.currentReciter?.displayName ?? "Reciter"
        info[MPMediaItemPropertyArtist] = reciterName
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
        seekingToStart = false
        isPlaying = true

        guard let url = URL(string: verseData.au) else { return }
        audioService.playWithSeek(url: url, seekMs: verseData.vs, rate: playbackSpeed)

        updateNowPlaying()
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
        seekingToStart = false
        tappedWordPosition = nil
        tappedVerseId = nil
        if let obs = tapObserver { NotificationCenter.default.removeObserver(obs) }
        tapObserver = nil
        wordPlayer?.pause()
        wordPlayer = nil
        audioService.stop()
        clearNowPlaying()
    }

    func pauseTracking() {
        trackingTask?.cancel()
        trackingTask = nil
        tappedWordPosition = nil
        tappedVerseId = nil
        if let obs = tapObserver { NotificationCenter.default.removeObserver(obs) }
        tapObserver = nil
        wordPlayer?.pause()
        wordPlayer = nil
    }

    func resumeTracking() {
        guard audioService.isPlaying || audioService.isFollowAlongActive,
              currentSurahId != nil, currentVerseId != nil else { return }
        currentWordIndex = nil
        isPlaying = audioService.isPlaying
        startWordTracking()
    }

    func togglePlayPause() {
        guard isPlaying || currentVerseId != nil else { return }
        audioService.togglePause()
        isPlaying = audioService.isPlaying
        updateNowPlaying()
    }

    func setLoopCount(_ count: Int) {
        loopCount = count
        currentLoop = 0
    }

    func setSpeed(_ speed: Float) {
        let clamped = min(max(speed, 0.5), 1.25)
        playbackSpeed = clamped
        if isPlaying {
            audioService.setRate(clamped)
        }
    }

    func tapWord(_ word: QuranWord, verseId: Int) {
        if let obs = tapObserver { NotificationCenter.default.removeObserver(obs) }
        wordPlayer?.pause()
        wordPlayer = nil

        tappedWordPosition = word.p
        tappedVerseId = verseId

        guard let audioURL = word.audioURL else { return }
        let item = AVPlayerItem(url: audioURL)
        let player = AVPlayer(playerItem: item)
        wordPlayer = player

        tapObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tappedWordPosition = nil
                self?.tappedVerseId = nil
            }
        }

        player.play()
    }

    func highlightState(for word: QuranWord, verseId: Int) -> WordHighlightState {
        if tappedWordPosition == word.p && tappedVerseId == verseId {
            return .current
        }
        guard currentVerseId == verseId, let idx = currentWordIndex else { return .upcoming }
        let wordIdx = word.p - 1
        if wordIdx == idx { return .current }
        if wordIdx < idx { return .completed }
        return .upcoming
    }

    func nextVerse() {
        guard let surahId = currentSurahId, let verseId = currentVerseId else { return }
        let totalVerses = dataService.surah(id: surahId)?.totalVerses ?? 0
        guard verseId < totalVerses else { return }
        if !seekToVerseInPlace(surahId: surahId, ayahId: verseId + 1) {
            playVerse(surahId: surahId, ayahId: verseId + 1)
        }
    }

    func previousVerse() {
        guard let surahId = currentSurahId, let verseId = currentVerseId else { return }
        guard verseId > 1 else { return }
        if !seekToVerseInPlace(surahId: surahId, ayahId: verseId - 1) {
            playVerse(surahId: surahId, ayahId: verseId - 1)
        }
    }

    /// Seek within the existing player for per-surah reciters. Returns true if handled.
    private func seekToVerseInPlace(surahId: Int, ayahId: Int) -> Bool {
        guard let reciter = wordDataService.currentReciter, !reciter.hasPerVerseAudio,
              let verseData = wordDataService.words(surahId: surahId, ayahId: ayahId) else { return false }
        trackingTask?.cancel()
        currentVerseId = ayahId
        currentWordIndex = 0
        currentLoop = 0
        seekingToStart = true
        audioService.seekTo(ms: verseData.vs, completion: nil)
        audioService.setRate(playbackSpeed)
        updateNowPlaying()
        startWordTracking()
        return true
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

                if self.seekingToStart {
                    if timeMs < verseData.ve {
                        self.seekingToStart = false
                    } else {
                        try? await Task.sleep(for: .milliseconds(30))
                        continue
                    }
                }

                if timeMs >= verseData.ve {
                    self.handleVerseEnd()
                    return
                }

                let idx = Self.wordIndex(for: timeMs, in: verseData.w)
                if idx != self.currentWordIndex {
                    self.currentWordIndex = idx
                }

                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func handleVerseEnd() {
        currentLoop += 1
        if currentLoop < loopCount {
            guard let surahId = currentSurahId, let verseId = currentVerseId,
                  let verseData = wordDataService.words(surahId: surahId, ayahId: verseId) else { return }
            currentWordIndex = 0
            seekingToStart = true
            audioService.seekTo(ms: verseData.vs, completion: nil)
            audioService.setRate(playbackSpeed)
            startWordTracking()
        } else {
            if loopCount > 1 {
                loopCount = 1
                currentLoop = 0
            }
            if autoAdvance {
                advanceToNextVerse()
            } else {
                isPlaying = false
                currentWordIndex = nil
                audioService.stop()
                clearNowPlaying()
            }
        }
    }

    private func advanceToNextVerse() {
        guard let surahId = currentSurahId, let verseId = currentVerseId else { return }
        let totalVerses = dataService.surah(id: surahId)?.totalVerses ?? 0
        if verseId < totalVerses {
            let nextAyah = verseId + 1
            if let reciter = wordDataService.currentReciter, !reciter.hasPerVerseAudio,
               wordDataService.words(surahId: surahId, ayahId: nextAyah) != nil {
                // Per-surah reciter: audio is already playing at the right position,
                // just transition tracking without seeking.
                currentVerseId = nextAyah
                currentWordIndex = 0
                currentLoop = 0
                updateNowPlaying()
                startWordTracking()
            } else {
                playVerse(surahId: surahId, ayahId: nextAyah)
            }
        } else {
            isPlaying = false
            currentWordIndex = nil
            audioService.stop()
            clearNowPlaying()
        }
    }
}
