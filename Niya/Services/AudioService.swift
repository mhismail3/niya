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

/// Reciter playback speeds offered in the UI. Finer steps below 1x support memorization.
enum PlaybackSpeed {
    static let options: [Float] = [0.5, 0.6, 0.7, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]
    static let range: ClosedRange<Float> = 0.5...2.0

    static func clamped(_ rate: Float) -> Float {
        guard rate.isFinite else { return 1.0 }
        return min(max(rate, range.lowerBound), range.upperBound)
    }

    static func label(_ rate: Float) -> String {
        rate.formatted(.number.precision(.fractionLength(0...2))) + "x"
    }
}

@Observable
@MainActor
final class AudioService: AudioPlaying {
    var isPlaying = false
    var isLoading = false
    var currentVerseID: VerseID?
    var currentSurahId: Int?
    var isFollowAlongActive = false
    var onVerseDidFinish: ((VerseID) -> Void)?
    var onVerseDidChange: ((VerseID) -> Void)?
    var onPlaybackEnded: (() -> Void)?
    /// Fires when the player's actual playing/buffering state changes (e.g. to refresh Now Playing).
    var onPlaybackStateChange: (() -> Void)?
    private(set) var lastError: String?
    private(set) var isContinuousMode = false
    /// The single source of truth for reciter speed. Every player this service creates
    /// adopts it as `defaultRate`, so `play()` (resume, interruption recovery, new items)
    /// never silently falls back to 1x.
    private(set) var playbackRate: Float

    private let defaults: UserDefaults
    private var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var boundaryObserver: Any?
    private var verseTrackingObserver: Any?
    private var fadeTask: Task<Void, Never>?
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var playerGeneration = 0
    private var isSeekingToStart = false
    /// Short word-pronunciation clips play beside (never instead of) recitation.
    private var clipPlayer: AVPlayer?
    private var clipObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: StorageKey.playbackSpeed) as? Float
        self.playbackRate = PlaybackSpeed.clamped(stored ?? 1.0)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Creates the player for a new item with the current speed and a pitch-preserving
    /// algorithm suited to recitation at non-1x rates.
    private func makePlayer(item: AVPlayerItem) -> AVPlayer {
        item.audioTimePitchAlgorithm = .spectral
        let player = AVPlayer(playerItem: item)
        player.defaultRate = playbackRate
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self, weak player] observed, _ in
            let status = observed.timeControlStatus
            Task { @MainActor in
                guard let self, let player, self.player === player else { return }
                // "Playing" is the user's intent (playing or buffering toward it), so pause
                // and the play/pause control keep working while a stream loads. Until the
                // initial seek lands the player is paused but still loading.
                self.isPlaying = status != .paused
                self.isLoading = status == .waitingToPlayAtSpecifiedRate || (status == .paused && self.isSeekingToStart)
                self.onPlaybackStateChange?()
            }
        }
        return player
    }

    @objc nonisolated private func itemFailedNotification(_ notification: Notification) {
        let message = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
        let item = (notification.object as AnyObject?).map(ObjectIdentifier.init)
        Task { @MainActor in self.failCurrentItem(item: item, message: message) }
    }

    func clearError() { lastError = nil }

    private func failCurrentItem(item: ObjectIdentifier?, message: String?) {
        guard let currentItem, item == ObjectIdentifier(currentItem) else { return }
        lastError = message ?? currentItem.error?.localizedDescription ?? "Audio could not be played. Check your connection and try again."
        stop()
    }

    private func observeFailure(of item: AVPlayerItem) {
        NotificationCenter.default.addObserver(self, selector: #selector(itemFailedNotification(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: item)
        itemObservation = item.observe(\.status, options: [.new]) { [weak self, weak item] observed, _ in
            guard observed.status == .failed else { return }
            let message = observed.error?.localizedDescription
            let identity = item.map(ObjectIdentifier.init)
            Task { @MainActor in self?.failCurrentItem(item: identity, message: message) }
        }
    }

    var currentTimeMs: Int {
        guard let player else { return 0 }
        let seconds = CMTimeGetSeconds(player.currentTime())
        guard seconds.isFinite else { return 0 }
        return Int(seconds * 1000)
    }

    /// Sets the category only. The session is activated when recitation starts, so merely
    /// opening Niya (e.g. to check prayer times) never interrupts another app's audio.
    func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        } catch {
            AppLogger.audio.error("Session config error: \(error)")
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(interruptionNotification),
                           name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(routeChangeNotification),
                           name: AVAudioSession.routeChangeNotification, object: nil)
    }

    private var wasPlayingBeforeInterruption = false

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLogger.audio.error("Session activation error: \(error)")
        }
    }

    private func deactivateSession() {
        // Lets the app the user was listening to before (podcast, music) resume.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // AVFoundation may post these off the main thread; hop explicitly rather than relying
    // on main-actor @objc entry points, which trap when invoked from another thread.
    @objc nonisolated private func interruptionNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        let options = AVAudioSession.InterruptionOptions(
            rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        )
        Task { @MainActor in self.handleInterruption(type, options: options) }
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            isPlaying = false
        case .ended:
            // Never resume audio the user had paused before the call/alarm.
            guard wasPlayingBeforeInterruption, options.contains(.shouldResume), let player else { return }
            wasPlayingBeforeInterruption = false
            activateSession()
            player.play()
            isPlaying = true
        @unknown default:
            break
        }
    }

    @objc nonisolated private func routeChangeNotification(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        // Headphones unplugged / Bluetooth lost: AVPlayer pauses itself; mirror that state.
        Task { @MainActor in
            guard self.isPlaying, let player = self.player, player.timeControlStatus == .paused else { return }
            self.isPlaying = false
        }
    }

    func play(url: URL, verseID: VerseID? = nil, surahId: Int? = nil) {
        resetPlayer()
        activateSession()
        isLoading = true
        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = makePlayer(item: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        observeFailure(of: item)

        player?.play()
    }

    /// Transition to a new verse without tearing down the player (keeps audio session alive in background).
    func transitionToVerse(url: URL, verseID: VerseID, surahId: Int) {
        if let currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: currentItem)
        }
        itemObservation = nil
        if let obs = boundaryObserver, let player {
            player.removeTimeObserver(obs)
        }
        boundaryObserver = nil

        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .spectral
        currentItem = item
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        observeFailure(of: item)

        activateSession()
        if let player {
            player.replaceCurrentItem(with: item)
            player.play()
        } else {
            player = makePlayer(item: item)
            player?.play()
        }

        isLoading = true
    }

    /// Play a single verse segment from a surah file, with fade-out at end.
    func playVerseInSurah(url: URL, startMs: Int, endMs: Int, verseID: VerseID, surahId: Int) {
        resetPlayer()
        activateSession()
        isLoading = true
        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = makePlayer(item: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        observeFailure(of: item)
        let seekTime = CMTime(value: Int64(startMs), timescale: 1000)
        let endTime = CMTime(value: Int64(endMs), timescale: 1000)
        let generation = playerGeneration
        let expectedPlayer = player

        isSeekingToStart = true
        player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                guard finished, let self, self.playerGeneration == generation,
                      let player = self.player, player === expectedPlayer else { return }
                self.isSeekingToStart = false
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
        resetPlayer()
        activateSession()
        guard let first = boundaries.first else { return }
        isContinuousMode = true
        isLoading = true
        currentVerseID = first.verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = makePlayer(item: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        observeFailure(of: item)
        let seekTime = CMTime(value: Int64(first.startMs), timescale: 1000)
        let lastEndMs = boundaries.last?.endMs ?? first.endMs
        let generation = playerGeneration
        let expectedPlayer = player

        isSeekingToStart = true
        player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                guard finished, let self, self.playerGeneration == generation,
                      let player = self.player, player === expectedPlayer else { return }
                self.isSeekingToStart = false

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
                            self.onPlaybackEnded?()
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

    func playWithSeek(url: URL, seekMs: Int) {
        resetPlayer()
        activateSession()
        isFollowAlongActive = true
        isLoading = true

        let item = AVPlayerItem(url: url)
        currentItem = item
        player = makePlayer(item: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        observeFailure(of: item)
        let seekTime = CMTime(value: Int64(seekMs), timescale: 1000)
        let generation = playerGeneration
        let expectedPlayer = player
        isSeekingToStart = true
        player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                guard finished, let self, self.playerGeneration == generation,
                      let player = self.player, player === expectedPlayer else { return }
                self.isSeekingToStart = false
                player.play()
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

    /// Changes speed only; it never starts or resumes playback.
    func setRate(_ rate: Float) {
        let clamped = PlaybackSpeed.clamped(rate)
        playbackRate = clamped
        defaults.set(clamped, forKey: StorageKey.playbackSpeed)
        guard let player else { return }
        player.defaultRate = clamped
        if isPlaying { player.rate = clamped }
    }

    private func fadeOutAndStop(duration: TimeInterval = 0.5, steps: Int = 15) {
        guard let player else { stop(); return }
        fadeTask?.cancel()
        let interval = duration / Double(steps)
        let initialVolume = player.volume
        fadeTask = Task { [weak self] in
            for i in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                guard !Task.isCancelled, let self else { return }
                if i == steps {
                    self.stop()
                } else {
                    self.player?.volume = initialVolume * Float(steps - i) / Float(steps)
                }
            }
        }
    }

    /// Ends playback and releases the audio session so other apps can resume.
    func stop() {
        let hadPlayer = player != nil
        resetPlayer()
        if hadPlayer && clipPlayer == nil { deactivateSession() }
    }

    /// Plays a short word clip without disturbing recitation state.
    func playClip(url: URL, onFinish: @escaping @MainActor () -> Void) {
        stopClip()
        activateSession()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        clipPlayer = player
        clipObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopClip()
                onFinish()
            }
        }
        player.play()
    }

    func stopClip() {
        if let clipObserver { NotificationCenter.default.removeObserver(clipObserver) }
        clipObserver = nil
        guard let clipPlayer else { return }
        clipPlayer.pause()
        self.clipPlayer = nil
        if player == nil { deactivateSession() }
    }

    /// Tears down the current player without releasing the session (used between items).
    private func resetPlayer() {
        playerGeneration += 1
        isSeekingToStart = false
        playerObservation = nil
        itemObservation = nil
        fadeTask?.cancel()
        fadeTask = nil
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
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: currentItem)
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
        activateSession()
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

    /// The returned token remembers its player: AVPlayer raises if asked to remove an
    /// observer that a different (since replaced) player registered.
    func addPeriodicTimeObserver(intervalMs: Int, callback: @escaping @Sendable (Int) -> Void) -> Any? {
        guard let player else { return nil }
        let interval = CMTime(value: Int64(intervalMs), timescale: 1000)
        let token = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let ms = Int(CMTimeGetSeconds(time) * 1000)
            guard ms >= 0 else { return }
            callback(ms)
        }
        return PlayerTimeObserver(player: player, token: token)
    }

    func removeTimeObserver(_ observer: Any) {
        guard let observer = observer as? PlayerTimeObserver else { return }
        observer.remove()
    }

    @objc nonisolated private func playerItemDidFinish(_ notification: Notification) {
        let finished = (notification.object as AnyObject?).map(ObjectIdentifier.init)
        Task { @MainActor in self.playerDidFinish(item: finished) }
    }

    private func playerDidFinish(item: ObjectIdentifier?) {
        // Ignore a late notification for an item that has since been replaced.
        guard let currentItem, item == ObjectIdentifier(currentItem) else { return }
        if isFollowAlongActive || isContinuousMode {
            onPlaybackEnded?()
            stop()
        } else {
            let itemBefore = player?.currentItem
            if let vid = currentVerseID {
                onVerseDidFinish?(vid)
            }
            if player?.currentItem === itemBefore || player == nil {
                isPlaying = false
                isLoading = false
                currentVerseID = nil
                currentSurahId = nil
                deactivateSession()
                onPlaybackEnded?()
            }
        }
    }
}

private final class PlayerTimeObserver {
    private weak var player: AVPlayer?
    private var token: Any?

    init(player: AVPlayer, token: Any) {
        self.player = player
        self.token = token
    }

    func remove() {
        if let token { player?.removeTimeObserver(token) }
        token = nil
    }
}
