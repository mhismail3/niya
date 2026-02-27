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
    var downloadProgress: Double = 0
    var isFollowAlongActive = false
    var onVerseDidFinish: ((VerseID) -> Void)?
    private(set) var isContinuousMode = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var boundaryObserver: Any?
    private var verseTrackingObserver: Any?

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
            print("[AudioService] Session config error: \(error)")
        }
    }

    func play(url: URL, verseID: VerseID? = nil, surahId: Int? = nil) {
        stop()
        isLoading = true
        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
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

    /// Play a single verse segment from a surah file, with fade-out at end.
    func playVerseInSurah(url: URL, startMs: Int, endMs: Int, verseID: VerseID, surahId: Int) {
        stop()
        isLoading = true
        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
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
                    Task { @MainActor in self?.fadeOutAndStop() }
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
        let seekTime = CMTime(value: Int64(startMs), timescale: 1000)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func playWithSeek(url: URL, seekMs: Int, rate: Float) {
        stop()
        isFollowAlongActive = true
        isLoading = true

        let item = AVPlayerItem(url: url)
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

    func seekTo(ms: Int) {
        let time = CMTime(value: Int64(ms), timescale: 1000)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
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
        player?.volume = 1.0
        player?.pause()
        player = nil
        isPlaying = false
        isFollowAlongActive = false
        isContinuousMode = false
        currentVerseID = nil
        currentSurahId = nil
    }

    func togglePause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
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
        let url = documentsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func downloadSurah(surahId: Int, reciter: Reciter) async throws -> URL {
        let remote = surahStreamURL(surahId: surahId, reciter: reciter)
        let localURL = documentsDirectory.appendingPathComponent(reciter.localFilename(for: surahId))

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        downloadProgress = 0
        let (tempURL, _) = try await URLSession.shared.download(from: remote)
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        downloadProgress = 1
        return localURL
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    @objc private func playerDidFinish() {
        if isFollowAlongActive || isContinuousMode {
            stop()
        } else {
            let playerBefore = player
            if let vid = currentVerseID {
                onVerseDidFinish?(vid)
            }
            if player === playerBefore {
                isPlaying = false
                currentVerseID = nil
                currentSurahId = nil
            }
        }
    }
}
