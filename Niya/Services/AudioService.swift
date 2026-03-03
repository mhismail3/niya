import Foundation
import AVFoundation

struct VerseID: Hashable, Sendable {
    let surahId: Int
    let ayahId: Int
}

struct VerseBoundary: Sendable {
    let verseID: VerseID
    let startMs: Int
    let endMs: Int
}

@Observable
@MainActor
final class AudioService {
    var isPlaying = false
    var isLoading = false
    var currentVerseID: VerseID?
    var currentSurahId: Int?
    var isFollowAlongActive = false
    var onVerseDidFinish: ((VerseID) -> Void)?
    var onVerseDidChange: ((VerseID) -> Void)?
    private(set) var isContinuousMode = false

    private var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var boundaryObserver: Any?
    private var verseTrackingObserver: Any?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var currentTimeMs: Int {
        guard let player else { return 0 }
        let seconds = CMTimeGetSeconds(player.currentTime())
        guard seconds.isFinite else { return 0 }
        return Int(seconds * 1000)
    }

    func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLogger.audio.error("Session config error: \(error)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            isPlaying = false
        } else if type == .ended,
                  let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                player?.play()
                isPlaying = true
            }
        }
    }

    func play(url: URL, verseID: VerseID? = nil, surahId: Int? = nil) {
        stop()
        isLoading = true
        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = AVPlayer(playerItem: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        player?.play()
        isPlaying = true
        isLoading = false
    }

    /// Transition to a new verse without tearing down the player (keeps audio session alive in background).
    func transitionToVerse(url: URL, verseID: VerseID, surahId: Int) {
        if let currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        if let obs = boundaryObserver, let player {
            player.removeTimeObserver(obs)
        }
        boundaryObserver = nil

        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        currentItem = item
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        if let player {
            player.replaceCurrentItem(with: item)
            player.play()
        } else {
            player = AVPlayer(playerItem: item)
            player?.play()
        }

        isPlaying = true
        isLoading = false
    }

    /// Play a single verse segment from a surah file, with fade-out at end.
    func playVerseInSurah(url: URL, startMs: Int, endMs: Int, verseID: VerseID, surahId: Int) {
        stop()
        isLoading = true
        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = AVPlayer(playerItem: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        let seekTime = CMTime(value: Int64(startMs), timescale: 1000)
        let endTime = CMTime(value: Int64(endMs), timescale: 1000)

        player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.boundaryObserver = player.addBoundaryTimeObserver(
                    forTimes: [NSValue(time: endTime)],
                    queue: .main
                ) { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        let itemBefore = self.player?.currentItem
                        if let vid = self.currentVerseID {
                            self.onVerseDidFinish?(vid)
                        }
                        if self.player?.currentItem === itemBefore || self.player == nil {
                            self.fadeOutAndStop()
                        }
                    }
                }
                player.play()
                self.isPlaying = true
                self.isLoading = false
            }
        }
    }

    /// Play surah audio continuously, tracking verse position as it progresses.
    func playSurahContinuous(url: URL, boundaries: [VerseBoundary], surahId: Int) {
        stop()
        guard let first = boundaries.first else { return }
        isContinuousMode = true
        isLoading = true
        currentVerseID = first.verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = AVPlayer(playerItem: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        let seekTime = CMTime(value: Int64(first.startMs), timescale: 1000)
        let lastEndMs = boundaries.last?.endMs ?? first.endMs

        player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }

                let interval = CMTime(value: 200, timescale: 1000)
                self.verseTrackingObserver = player.addPeriodicTimeObserver(
                    forInterval: interval, queue: .main
                ) { [weak self] time in
                    Task { @MainActor in
                        guard let self, self.isContinuousMode else { return }
                        let ms = Int(CMTimeGetSeconds(time) * 1000)

                        for b in boundaries.reversed() {
                            if ms >= b.startMs {
                                if self.currentVerseID != b.verseID {
                                    self.currentVerseID = b.verseID
                                    self.onVerseDidChange?(b.verseID)
                                }
                                break
                            }
                        }

                        if ms >= lastEndMs {
                            self.stop()
                        }
                    }
                }

                player.play()
                self.isPlaying = true
                self.isLoading = false
            }
        }
    }

    /// Seek to a verse within an already-playing continuous session.
    func seekToVerse(_ verseID: VerseID, startMs: Int) {
        guard isContinuousMode, let player else { return }
        currentVerseID = verseID
        onVerseDidChange?(verseID)
        let seekTime = CMTime(value: Int64(startMs), timescale: 1000)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func playWithSeek(url: URL, seekMs: Int, rate: Float) {
        stop()
        isFollowAlongActive = true
        isLoading = true

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = AVPlayer(playerItem: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        let seekTime = CMTime(value: Int64(seekMs), timescale: 1000)
        player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.player?.rate = rate
                self.isPlaying = true
                self.isLoading = false
            }
        }
    }

    func seekTo(ms: Int, completion: (@Sendable () -> Void)? = nil) {
        let time = CMTime(value: Int64(ms), timescale: 1000)
        if let completion {
            player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                Task { @MainActor in completion() }
            }
        } else {
            player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func setRate(_ rate: Float) {
        player?.rate = rate
        if rate > 0 { isPlaying = true }
    }

    private func fadeOutAndStop(duration: TimeInterval = 0.5, steps: Int = 15) {
        guard let player else { stop(); return }
        let interval = duration / Double(steps)
        let initialVolume = player.volume
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                guard let self else { return }
                if i == steps {
                    self.stop()
                } else {
                    self.player?.volume = initialVolume * Float(steps - i) / Float(steps)
                }
            }
        }
    }

    func stop() {
        if let obs = boundaryObserver, let player {
            player.removeTimeObserver(obs)
        }
        boundaryObserver = nil
        if let obs = verseTrackingObserver, let player {
            player.removeTimeObserver(obs)
        }
        verseTrackingObserver = nil
        if let currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        currentItem = nil
        player?.volume = 1.0
        player?.pause()
        player = nil
        isPlaying = false
        isFollowAlongActive = false
        isContinuousMode = false
        currentVerseID = nil
        currentSurahId = nil
    }

    func pause() {
        guard let player, isPlaying else { return }
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard let player, !isPlaying else { return }
        player.play()
        isPlaying = true
    }

    func togglePause() {
        guard player != nil else { return }
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func streamURL(absoluteVerseNumber: Int, reciter: Reciter) -> URL? {
        reciter.verseStreamURL(absoluteVerseNumber: absoluteVerseNumber)
    }

    func surahStreamURL(surahId: Int, reciter: Reciter) -> URL {
        reciter.surahStreamURL(surahId: surahId)
    }

    func localSurahURL(surahId: Int, reciter: Reciter) -> URL? {
        let filename = reciter.localFilename(for: surahId)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @objc private func playerDidFinish() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.playerDidFinish() }
            return
        }
        if isFollowAlongActive || isContinuousMode {
            stop()
        } else {
            let itemBefore = player?.currentItem
            if let vid = currentVerseID {
                onVerseDidFinish?(vid)
            }
            if player?.currentItem === itemBefore || player == nil {
                isPlaying = false
                currentVerseID = nil
                currentSurahId = nil
            }
        }
    }
}
